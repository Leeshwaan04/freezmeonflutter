"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.redisSub = exports.redisPub = exports.redis = void 0;
const ioredis_1 = __importDefault(require("ioredis"));
const REDIS_URL = process.env.REDIS_URL ?? 'redis://127.0.0.1:6379';
// Primary client — commands
exports.redis = new ioredis_1.default(REDIS_URL, {
    maxRetriesPerRequest: 3,
    lazyConnect: false,
    enableReadyCheck: true,
});
// Duplicate client for pub/sub (socket.io adapter requires separate connections)
exports.redisPub = new ioredis_1.default(REDIS_URL, { maxRetriesPerRequest: null });
exports.redisSub = new ioredis_1.default(REDIS_URL, { maxRetriesPerRequest: null });
exports.redis.on('error', (err) => console.error('[Redis] error:', err.message));
exports.redis.on('connect', () => console.log('[Redis] connected'));
//# sourceMappingURL=redis.js.map