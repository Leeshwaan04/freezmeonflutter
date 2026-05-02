import { Server, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { redisPub, redisSub } from '../db/redis';
import { verifyAccessToken } from '../services/jwt';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';
import { logger } from '../services/logger';
import { sanitizeText } from '../utils/validate';

export function applyRedisAdapter(io: Server): void {
  io.adapter(createAdapter(redisPub, redisSub));
  logger.info('[Socket] Redis adapter attached — multi-node ready');
}

// Simple in-memory rate limiter for socket events (resets on server restart — acceptable for WS)
const _socketRateLimits = new Map<string, { count: number; resetAt: number }>();
function socketRateLimit(uid: string, event: string, maxPerWindow: number, windowMs: number): boolean {
  const key = `${uid}:${event}`;
  const now = Date.now();
  const bucket = _socketRateLimits.get(key);
  if (!bucket || now >= bucket.resetAt) {
    _socketRateLimits.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }
  if (bucket.count >= maxPerWindow) return false;
  bucket.count++;
  return true;
}

export function setupSocket(io: Server): void {
  // JWT auth middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) { next(new Error('Authentication required')); return; }
    try {
      const payload = verifyAccessToken(token);
      (socket as any).uid = payload.uid;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const uid = (socket as any).uid as string;
    socket.join(`user:${uid}`);   // personal room — all devices receive events
    logger.info({ msg: 'socket_connected', uid, socketId: socket.id });

    prisma.user.update({ where: { id: uid }, data: { lastActiveAt: new Date() } }).catch(() => {});

    // ── CHAT: SEND ──────────────────────────────────────────────────────────

    socket.on('chat:send', async ({
      chatId,
      text,
      clientMsgId,
    }: { chatId: string; text: string; clientMsgId?: string }) => {
      try {
        if (!socketRateLimit(uid, 'chat:send', 20, 60_000)) return; // 20 messages/min
        if (!text || typeof text !== 'string' || text.trim().length === 0 || text.length > 2000) return;
        const safeText = sanitizeText(text.trim());
        if (!safeText) return;
        const chat = await prisma.chat.findUnique({ where: { id: chatId } });
        if (!chat || !chat.members.includes(uid)) return;

        const message = await prisma.message.create({
          data: { chatId, senderUid: uid, text: safeText, status: 'sent' },
        });

        await prisma.chat.update({ where: { id: chatId }, data: { updatedAt: new Date() } });

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
              const delivered = await prisma.message.update({
                where: { id: message.id },
                data: { status: 'delivered', deliveredAt: new Date() },
              });
              socket.emit('chat:ack', { messageId: message.id, status: 'delivered' });
              io.to(room).emit('chat:status', { chatId, messageId: message.id, status: 'delivered' });
            } else {
              // Recipient offline — send push
              const recipientUser = await prisma.user.findUnique({ where: { id: member } });
              if (recipientUser?.fcmToken) {
                const senderProfile = await prisma.profile.findUnique({ where: { userId: uid } });
                const pushPreview = safeText.length > 80 ? `${safeText.slice(0, 80)}…` : safeText;
                await enqueuePush(
                  recipientUser.fcmToken,
                  senderProfile?.name ?? 'New message',
                  pushPreview,
                  { type: 'chat_message', chatId, messageId: message.id }
                );
              }
            }
          }
        }
      } catch (err) {
        logger.error({ msg: 'socket_chat_send_error', err });
      }
    });

    // ── CHAT: READ ──────────────────────────────────────────────────────────

    socket.on('chat:read', async ({ chatId, messageId }: { chatId: string; messageId: string }) => {
      try {
        const chat = await prisma.chat.findUnique({ where: { id: chatId } });
        if (!chat || !chat.members.includes(uid)) return; // must be a member

        const message = await prisma.message.update({
          where: { id: messageId },
          data: { status: 'read', readAt: new Date() },
        });

        for (const member of chat.members) {
          io.to(`user:${member}`).emit('chat:status', {
            chatId,
            messageId,
            status: 'read',
            readAt: message.readAt,
          });
        }
      } catch (err) {
        logger.error({ msg: 'socket_chat_read_error', err });
      }
    });

    // ── PRESENCE ────────────────────────────────────────────────────────────

    socket.on('presence:ping', async () => {
      await prisma.user.update({ where: { id: uid }, data: { lastActiveAt: new Date() } }).catch(() => {});
    });

    // ── BLINDS: REVEAL ──────────────────────────────────────────────────────

    socket.on('blind:reveal', async ({ sessionId }: { sessionId: string }) => {
      try {
        if (!socketRateLimit(uid, 'blind:reveal', 5, 60_000)) return;
        const session = await prisma.blindsSession.findUnique({ where: { id: sessionId } });
        if (!session || session.phase === 'ended') return;
        if (session.userA !== uid && session.userB !== uid) return;

        const isA = session.userA === uid;
        // Idempotent: only update if not already revealed by this user
        const updated = await prisma.blindsSession.update({
          where: { id: sessionId, ...(isA ? { revealA: false } : { revealB: false }) },
          data: isA ? { revealA: true } : { revealB: true },
        }).catch(() => prisma.blindsSession.findUnique({ where: { id: sessionId } }));

        if (!updated) return;
        io.to(`user:${session.userA}`).emit('blind:phase_change', { sessionId, session: updated });
        io.to(`user:${session.userB}`).emit('blind:phase_change', { sessionId, session: updated });
      } catch (err) {
        logger.error({ msg: 'socket_blind_reveal_error', err });
      }
    });

    // ── FREEZE ROOM: JOIN SOCKET ROOM ───────────────────────────────────────

    socket.on('freeze_room:join', async ({ roomId }: { roomId: string }) => {
      try {
        if (!socketRateLimit(uid, 'freeze_room:join', 10, 60_000)) return;
        // Verify user is a participant in this room before subscribing to events
        const participant = await prisma.freezeRoomParticipant.findUnique({
          where: { roomId_uid: { roomId, uid } },
        });
        if (!participant) return;
        socket.join(`freeze_room:${roomId}`);
        logger.info({ msg: 'freeze_room_socket_joined', uid, roomId });
      } catch (err) {
        logger.error({ msg: 'freeze_room_join_error', err });
      }
    });

    socket.on('freeze_room:leave', ({ roomId }: { roomId: string }) => {
      socket.leave(`freeze_room:${roomId}`);
    });

    // ── DISCONNECT ──────────────────────────────────────────────────────────

    socket.on('disconnect', (reason) => {
      logger.info({ msg: 'socket_disconnected', uid, reason });
    });
  });
}
