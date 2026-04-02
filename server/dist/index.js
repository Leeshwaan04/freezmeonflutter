"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.io = void 0;
require("dotenv/config");
require("./services/logger"); // init logger first (patches console.*)
const express_1 = __importDefault(require("express"));
const http_1 = __importDefault(require("http"));
const socket_io_1 = require("socket.io");
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const logger_1 = require("./services/logger");
const requestLogger_1 = require("./middleware/requestLogger");
const rateLimiter_1 = require("./middleware/rateLimiter");
const idempotency_1 = require("./middleware/idempotency");
const auth_1 = __importDefault(require("./routes/auth"));
const profiles_1 = __importDefault(require("./routes/profiles"));
const matching_1 = __importDefault(require("./routes/matching"));
const chat_1 = __importDefault(require("./routes/chat"));
const melt_1 = __importDefault(require("./routes/melt"));
const paths_1 = __importDefault(require("./routes/paths"));
const blinds_1 = __importDefault(require("./routes/blinds"));
const iap_1 = __importDefault(require("./routes/iap"));
const storage_1 = __importDefault(require("./routes/storage"));
const feed_1 = __importDefault(require("./routes/feed"));
const users_1 = __importDefault(require("./routes/users"));
const socket_1 = require("./realtime/socket");
const queues_1 = require("./jobs/queues");
const app = (0, express_1.default)();
const httpServer = http_1.default.createServer(app);
const io = new socket_io_1.Server(httpServer, {
    cors: {
        origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*',
        methods: ['GET', 'POST'],
        credentials: true,
    },
    transports: ['websocket', 'polling'],
});
exports.io = io;
// Apply Redis adapter for multi-node socket.io
(0, socket_1.applyRedisAdapter)(io);
// ── Middleware ──────────────────────────────────────────────────────────────
app.set('trust proxy', 1); // behind nginx
app.use((0, helmet_1.default)());
app.use((0, cors_1.default)({ origin: process.env.ALLOWED_ORIGINS?.split(',') ?? '*', credentials: true }));
app.use(express_1.default.json({ limit: '1mb' }));
app.use(requestLogger_1.requestLogger);
app.use(rateLimiter_1.globalLimiter);
// ── Routes ──────────────────────────────────────────────────────────────────
app.use('/auth', rateLimiter_1.authLimiter, auth_1.default);
app.use('/profiles', profiles_1.default);
app.use('/matching', rateLimiter_1.actionLimiter, idempotency_1.idempotent, matching_1.default);
app.use('/chats', chat_1.default);
app.use('/melt', rateLimiter_1.actionLimiter, idempotency_1.idempotent, melt_1.default);
app.use('/paths', paths_1.default);
app.use('/blinds', rateLimiter_1.actionLimiter, blinds_1.default);
app.use('/iap', iap_1.default);
app.use('/storage', storage_1.default);
app.use('/feed', feed_1.default);
app.use('/users', users_1.default);
app.get('/health', (_req, res) => res.json({ status: 'ok', ts: new Date().toISOString() }));
// Global error handler
app.use((err, _req, res, _next) => {
    logger_1.logger.error({ msg: 'unhandled_error', error: err.message, stack: err.stack });
    res.status(500).json({ error: 'Internal server error' });
});
// ── WebSockets ──────────────────────────────────────────────────────────────
(0, socket_1.setupSocket)(io);
// ── Start ───────────────────────────────────────────────────────────────────
const PORT = parseInt(process.env.PORT ?? '3000', 10);
httpServer.listen(PORT, '0.0.0.0', async () => {
    logger_1.logger.info(`[server] Freezme API on port ${PORT}`);
    await (0, queues_1.scheduleRecurringJobs)();
});
//# sourceMappingURL=index.js.map