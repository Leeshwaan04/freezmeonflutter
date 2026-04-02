"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.idempotent = idempotent;
const redis_1 = require("../db/redis");
const TTL_SECONDS = 86400; // 24 hours
/**
 * Idempotency middleware — attach to any mutating endpoint (POST like/skip/send).
 * Client sends `Idempotency-Key: <uuid>` header.
 * First call executes and stores the response; subsequent calls with the same
 * key return the cached response without re-executing.
 */
function idempotent(req, res, next) {
    const key = req.headers['idempotency-key'];
    if (!key) {
        next();
        return;
    }
    const redisKey = `idempotency:${req.uid ?? 'anon'}:${key}`;
    redis_1.redis.get(redisKey).then((cached) => {
        if (cached) {
            const { status, body } = JSON.parse(cached);
            res.status(status).json(body);
            return;
        }
        // Patch res.json to capture the response
        const originalJson = res.json.bind(res);
        res.json = (body) => {
            if (res.statusCode < 500) {
                redis_1.redis.setex(redisKey, TTL_SECONDS, JSON.stringify({ status: res.statusCode, body })).catch(() => { });
            }
            return originalJson(body);
        };
        next();
    }).catch(() => next());
}
//# sourceMappingURL=idempotency.js.map