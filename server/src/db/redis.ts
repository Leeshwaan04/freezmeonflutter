import Redis from 'ioredis';

const REDIS_URL = process.env.REDIS_URL ?? 'redis://127.0.0.1:6379';

// Primary client — commands
export const redis = new Redis(REDIS_URL, {
  maxRetriesPerRequest: 3,
  lazyConnect: false,
  enableReadyCheck: true,
});

// Duplicate client for pub/sub (socket.io adapter requires separate connections)
export const redisPub = new Redis(REDIS_URL, { maxRetriesPerRequest: null });
export const redisSub = new Redis(REDIS_URL, { maxRetriesPerRequest: null });

redis.on('error', (err) => console.error('[Redis] error:', err.message));
redis.on('connect', () => console.log('[Redis] connected'));
