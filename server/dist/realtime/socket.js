"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.applyRedisAdapter = applyRedisAdapter;
exports.setupSocket = setupSocket;
const redis_adapter_1 = require("@socket.io/redis-adapter");
const redis_1 = require("../db/redis");
const jwt_1 = require("../services/jwt");
const client_1 = require("../db/client");
const queues_1 = require("../jobs/queues");
const logger_1 = require("../services/logger");
function applyRedisAdapter(io) {
    io.adapter((0, redis_adapter_1.createAdapter)(redis_1.redisPub, redis_1.redisSub));
    logger_1.logger.info('[Socket] Redis adapter attached — multi-node ready');
}
function setupSocket(io) {
    // JWT auth middleware
    io.use((socket, next) => {
        const token = socket.handshake.auth?.token;
        if (!token) {
            next(new Error('Authentication required'));
            return;
        }
        try {
            const payload = (0, jwt_1.verifyAccessToken)(token);
            socket.uid = payload.uid;
            next();
        }
        catch {
            next(new Error('Invalid token'));
        }
    });
    io.on('connection', (socket) => {
        const uid = socket.uid;
        socket.join(`user:${uid}`); // personal room — all devices receive events
        logger_1.logger.info({ msg: 'socket_connected', uid, socketId: socket.id });
        client_1.prisma.user.update({ where: { id: uid }, data: { lastActiveAt: new Date() } }).catch(() => { });
        // ── CHAT: SEND ──────────────────────────────────────────────────────────
        socket.on('chat:send', async ({ chatId, text, clientMsgId, }) => {
            try {
                const chat = await client_1.prisma.chat.findUnique({ where: { id: chatId } });
                if (!chat || !chat.members.includes(uid))
                    return;
                const message = await client_1.prisma.message.create({
                    data: { chatId, senderUid: uid, text, status: 'sent' },
                });
                await client_1.prisma.chat.update({ where: { id: chatId }, data: { updatedAt: new Date() } });
                // ACK back to sender: server received + stored
                socket.emit('chat:ack', { clientMsgId, messageId: message.id, status: 'sent' });
                // Deliver to ALL members
                for (const member of chat.members) {
                    const room = `user:${member}`;
                    io.to(room).emit('chat:message', { chatId, message });
                    // Mark delivered when the recipient is online
                    if (member !== uid) {
                        const memberSockets = await io.in(room).fetchSockets();
                        if (memberSockets.length > 0) {
                            // Recipient is online — mark delivered immediately
                            const delivered = await client_1.prisma.message.update({
                                where: { id: message.id },
                                data: { status: 'delivered', deliveredAt: new Date() },
                            });
                            socket.emit('chat:ack', { messageId: message.id, status: 'delivered' });
                            io.to(room).emit('chat:status', { chatId, messageId: message.id, status: 'delivered' });
                        }
                        else {
                            // Recipient offline — send push
                            const recipientUser = await client_1.prisma.user.findUnique({ where: { id: member } });
                            if (recipientUser?.fcmToken) {
                                const senderProfile = await client_1.prisma.profile.findUnique({ where: { userId: uid } });
                                await (0, queues_1.enqueuePush)(recipientUser.fcmToken, senderProfile?.name ?? 'New message', text.length > 80 ? `${text.slice(0, 80)}…` : text, { type: 'chat_message', chatId, messageId: message.id });
                            }
                        }
                    }
                }
            }
            catch (err) {
                logger_1.logger.error({ msg: 'socket_chat_send_error', err });
            }
        });
        // ── CHAT: READ ──────────────────────────────────────────────────────────
        socket.on('chat:read', async ({ chatId, messageId }) => {
            try {
                const message = await client_1.prisma.message.update({
                    where: { id: messageId },
                    data: { status: 'read', readAt: new Date() },
                });
                const chat = await client_1.prisma.chat.findUnique({ where: { id: chatId } });
                if (chat) {
                    for (const member of chat.members) {
                        io.to(`user:${member}`).emit('chat:status', {
                            chatId,
                            messageId,
                            status: 'read',
                            readAt: message.readAt,
                        });
                    }
                }
            }
            catch (err) {
                logger_1.logger.error({ msg: 'socket_chat_read_error', err });
            }
        });
        // ── PRESENCE ────────────────────────────────────────────────────────────
        socket.on('presence:ping', async () => {
            await client_1.prisma.user.update({ where: { id: uid }, data: { lastActiveAt: new Date() } }).catch(() => { });
        });
        // ── BLINDS: REVEAL ──────────────────────────────────────────────────────
        socket.on('blind:reveal', async ({ sessionId }) => {
            try {
                const session = await client_1.prisma.blindsSession.findUnique({ where: { id: sessionId } });
                if (!session)
                    return;
                if (session.userA !== uid && session.userB !== uid)
                    return;
                const isA = session.userA === uid;
                const updated = await client_1.prisma.blindsSession.update({
                    where: { id: sessionId },
                    data: isA ? { revealA: true } : { revealB: true },
                });
                io.to(`user:${session.userA}`).emit('blind:phase_change', { sessionId, session: updated });
                io.to(`user:${session.userB}`).emit('blind:phase_change', { sessionId, session: updated });
            }
            catch (err) {
                logger_1.logger.error({ msg: 'socket_blind_reveal_error', err });
            }
        });
        // ── DISCONNECT ──────────────────────────────────────────────────────────
        socket.on('disconnect', (reason) => {
            logger_1.logger.info({ msg: 'socket_disconnected', uid, reason });
        });
    });
}
//# sourceMappingURL=socket.js.map