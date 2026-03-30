import rateLimit from 'express-rate-limit';
import { RedisStore } from 'rate-limit-redis';
import { redis } from '../db/redis';

// eslint-disable-next-line @typescript-eslint/no-explicit-any
const sendCommand = (...args: string[]): any => redis.call(args[0], ...args.slice(1));

// Global rate limit — 200 req/min per IP
export const globalLimiter = rateLimit({
  windowMs: 60_000,
  max: 200,
  standardHeaders: true,
  legacyHeaders: false,
  store: new RedisStore({ sendCommand }),
  message: { error: 'Too many requests, please slow down.' },
});

// Auth endpoints — 10 attempts/min per IP (brute-force protection)
export const authLimiter = rateLimit({
  windowMs: 60_000,
  max: 10,
  standardHeaders: true,
  legacyHeaders: false,
  store: new RedisStore({ sendCommand }),
  message: { error: 'Too many auth attempts. Try again in a minute.' },
  skipSuccessfulRequests: true,
});

// Per-user action limiter (like, skip, message send) — 60/min
export const actionLimiter = rateLimit({
  windowMs: 60_000,
  max: 60,
  standardHeaders: true,
  legacyHeaders: false,
  keyGenerator: (req) => (req as any).uid ?? req.ip ?? 'anon',
  store: new RedisStore({ sendCommand }),
  message: { error: 'Slow down — too many actions.' },
});
