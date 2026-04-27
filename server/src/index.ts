import 'dotenv/config';
import './services/logger'; // init logger first (patches console.*)
import express from 'express';
import http from 'http';
import path from 'path';
import { Server as SocketIOServer } from 'socket.io';
import cors from 'cors';
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
  transports: ['websocket', 'polling'],
});

// Apply Redis adapter for multi-node socket.io
applyRedisAdapter(io);

// ── Middleware ──────────────────────────────────────────────────────────────

app.set('trust proxy', 1); // behind nginx
app.use(helmet());
app.use(cors({ origin: ALLOWED_ORIGINS, credentials: true }));
app.use(express.json({ limit: '1mb' }));
app.use(requestLogger);
app.use(globalLimiter);

// ── Routes ──────────────────────────────────────────────────────────────────

app.use('/auth', authLimiter, authRouter);
app.use('/profiles', profilesRouter);
app.use('/matching', actionLimiter, idempotent, matchingRouter);
app.use('/chats', chatRouter);
app.use('/melt', actionLimiter, idempotent, meltRouter);
app.use('/paths', actionLimiter, pathsRouter);
app.use('/blinds', actionLimiter, blindsRouter);
app.use('/iap', iapRouter);
app.use('/storage', storageRouter);
app.use('/feed', feedRouter);
app.use('/users', usersRouter);
app.use('/freeze-room', freezeRoomRouter);
app.use('/verification', verificationRouter);
app.use('/pool', poolRouter);

app.get('/health', (_req, res) => res.json({ status: 'ok', ts: new Date().toISOString(), v: '2026-04-05' }));
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

// Global error handler
app.use((err: Error, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  logger.error({ msg: 'unhandled_error', error: err.message, stack: err.stack });
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

export { io };
