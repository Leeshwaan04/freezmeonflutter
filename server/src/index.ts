import 'dotenv/config';

// ── Fail-fast env validation ─────────────────────────────────────────────────
const REQUIRED_ENV_VARS = [
  'DATABASE_URL',
  'JWT_SECRET',
  'JWT_REFRESH_SECRET',
  'REDIS_URL',
  'AWS_BUCKET_NAME',
];
const missingVars = REQUIRED_ENV_VARS.filter((v) => !process.env[v]);
if (missingVars.length > 0) {
  console.error(`[startup] FATAL: Missing required env vars: ${missingVars.join(', ')}`);
  process.exit(1);
}

import * as Sentry from '@sentry/node';

// Init Sentry before anything else so all errors are captured
if (process.env.SENTRY_DSN) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV ?? 'development',
    tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  });
}

import './services/logger'; // init logger first (patches console.*)
import express from 'express';
import http from 'http';
import path from 'path';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
import compression from 'compression';
import helmet from 'helmet';

import { logger } from './services/logger';
import { requestLogger } from './middleware/requestLogger';
import { globalLimiter, authLimiter, actionLimiter } from './middleware/rateLimiter';
import { idempotent } from './middleware/idempotency';

import authRouter from './routes/auth';
import profilesRouter from './routes/profiles';
import matchingRouter from './routes/matching';
import chatRouter from './routes/chat';
import meltRouter from './routes/melt';
import pathsRouter from './routes/paths';
import blindsRouter from './routes/blinds';
import iapRouter from './routes/iap';
import storageRouter from './routes/storage';
import feedRouter from './routes/feed';
import usersRouter from './routes/users';
import freezeRoomRouter from './routes/freezeroom';
import verificationRouter from './routes/verification';
import poolRouter from './routes/pool';

import { prisma } from './db/client';
import { redisPub } from './db/redis';
import { setupSocket, applyRedisAdapter } from './realtime/socket';
import { scheduleRecurringJobs } from './jobs/queues';

const app = express();
const httpServer = http.createServer(app);

const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map(o => o.trim())
  : process.env.NODE_ENV === 'production'
    ? ['https://api.freezme.in', 'https://freezme.in']
    : ['http://localhost:3000', 'http://localhost:8080'];

const io = new SocketIOServer(httpServer, {
  cors: {
    origin: ALLOWED_ORIGINS,
    methods: ['GET', 'POST'],
    credentials: true,
  },
  transports: process.env.NODE_ENV === 'production' ? ['websocket'] : ['websocket', 'polling'],
});

// Apply Redis adapter for multi-node socket.io
applyRedisAdapter(io);

// ── Middleware ──────────────────────────────────────────────────────────────

app.set('trust proxy', 1); // behind nginx
app.use(compression()); // gzip responses — ~60-70% bandwidth reduction
app.use(helmet());
app.use(cors({ origin: ALLOWED_ORIGINS, credentials: true }));
app.use(express.json({ limit: '1mb' }));
app.use(requestLogger);
app.use(globalLimiter);

// ── Routes ──────────────────────────────────────────────────────────────────

app.use('/auth', authLimiter, authRouter);
app.use('/profiles', profilesRouter);
app.use('/matching', actionLimiter, idempotent, matchingRouter);
app.use('/chats', actionLimiter, chatRouter);
app.use('/melt', actionLimiter, idempotent, meltRouter);
app.use('/paths', actionLimiter, pathsRouter);
app.use('/blinds', actionLimiter, blindsRouter);
app.use('/iap', actionLimiter, iapRouter);
app.use('/storage', storageRouter);
app.use('/feed', actionLimiter, feedRouter);
app.use('/users', usersRouter);
app.use('/freeze-room', freezeRoomRouter);
app.use('/verification', verificationRouter);
app.use('/pool', poolRouter);

app.get('/health', async (_req, res) => {
  const checks: Record<string, string> = {};
  let httpStatus = 200;

  // DB ping
  try {
    await prisma.$queryRaw`SELECT 1`;
    checks.db = 'ok';
  } catch {
    checks.db = 'error';
    httpStatus = 503;
  }

  // Redis ping
  try {
    await redisPub.ping();
    checks.redis = 'ok';
  } catch {
    checks.redis = 'error';
    httpStatus = 503;
  }

  res.status(httpStatus).json({ status: httpStatus === 200 ? 'ok' : 'degraded', ts: new Date().toISOString(), v: '2026-04-05', checks });
});
app.use('/public', express.static(path.join(__dirname, '../../public')));

// ── Static legal pages ───────────────────────────────────────────────────────
const publicDir = path.join(__dirname, '../public');
app.get('/terms', (_req, res) => {
  const file = path.join(publicDir, 'terms.html');
  res.sendFile(file, (err) => { if (err) res.status(404).send(`terms.html not found at ${file}`); });
});
app.get('/privacy', (_req, res) => {
  const file = path.join(publicDir, 'privacy.html');
  res.sendFile(file, (err) => { if (err) res.status(404).send(`privacy.html not found at ${file}`); });
});

// Global error handler — report to Sentry then respond
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error({ msg: 'unhandled_error', error: err.message, stack: err.stack });
  if (process.env.SENTRY_DSN) Sentry.captureException(err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── WebSockets ──────────────────────────────────────────────────────────────

setupSocket(io);

// ── Start ───────────────────────────────────────────────────────────────────

const PORT = parseInt(process.env.PORT ?? '3000', 10);
httpServer.listen(PORT, '0.0.0.0', async () => {
  logger.info(`[server] Freezme API on port ${PORT}`);
  await scheduleRecurringJobs();
});

// ── Graceful shutdown ────────────────────────────────────────────────────────

function shutdown(signal: string) {
  logger.info(`[server] ${signal} received — shutting down gracefully`);
  httpServer.close(async () => {
    logger.info('[server] HTTP server closed');
    try {
      await prisma.$disconnect();
      logger.info('[server] DB disconnected');
    } catch { /* ignore */ }
    process.exit(0);
  });
  // Force exit after 9s if connections don't drain (PM2 kill_timeout is 10s)
  setTimeout(() => {
    logger.error('[server] Forced shutdown after timeout');
    process.exit(1);
  }, 9000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

export { io };
