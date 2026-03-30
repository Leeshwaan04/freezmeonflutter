import { Request, Response, NextFunction } from 'express';
import { redis } from '../db/redis';

const TTL_SECONDS = 86_400; // 24 hours

/**
 * Idempotency middleware — attach to any mutating endpoint (POST like/skip/send).
 * Client sends `Idempotency-Key: <uuid>` header.
 * First call executes and stores the response; subsequent calls with the same
 * key return the cached response without re-executing.
 */
export function idempotent(req: Request, res: Response, next: NextFunction): void {
  const key = req.headers['idempotency-key'] as string | undefined;
  if (!key) { next(); return; }

  const redisKey = `idempotency:${(req as any).uid ?? 'anon'}:${key}`;

  redis.get(redisKey).then((cached) => {
    if (cached) {
      const { status, body } = JSON.parse(cached);
      res.status(status).json(body);
      return;
    }

    // Patch res.json to capture the response
    const originalJson = res.json.bind(res);
    res.json = (body: unknown) => {
      if (res.statusCode < 500) {
        redis.setex(redisKey, TTL_SECONDS, JSON.stringify({ status: res.statusCode, body })).catch(() => {});
      }
      return originalJson(body);
    };

    next();
  }).catch(() => next());
}
