"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.actionLimiter = exports.authLimiter = exports.globalLimiter = void 0;
const express_rate_limit_1 = __importDefault(require("express-rate-limit"));
const rate_limit_redis_1 = require("rate-limit-redis");
const redis_1 = require("../db/redis");
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const sendCommand = (...args) => redis_1.redis.call(args[0], ...args.slice(1));
// Global rate limit — 200 req/min per IP
exports.globalLimiter = (0, express_rate_limit_1.default)({
    windowMs: 60000,
    max: 200,
    standardHeaders: true,
    legacyHeaders: false,
    store: new rate_limit_redis_1.RedisStore({ sendCommand }),
    message: { error: 'Too many requests, please slow down.' },
});
// Auth endpoints — 10 attempts/min per IP (brute-force protection)
exports.authLimiter = (0, express_rate_limit_1.default)({
    windowMs: 60000,
    max: 10,
    standardHeaders: true,
    legacyHeaders: false,
    store: new rate_limit_redis_1.RedisStore({ sendCommand }),
    message: { error: 'Too many auth attempts. Try again in a minute.' },
    skipSuccessfulRequests: true,
});
// Per-user action limiter (like, skip, message send) — 60/min
exports.actionLimiter = (0, express_rate_limit_1.default)({
    windowMs: 60000,
    max: 60,
    standardHeaders: true,
    legacyHeaders: false,
    keyGenerator: (req) => req.uid ?? req.ip ?? 'anon',
    store: new rate_limit_redis_1.RedisStore({ sendCommand }),
    message: { error: 'Slow down — too many actions.' },
});
//# sourceMappingURL=rateLimiter.js.map