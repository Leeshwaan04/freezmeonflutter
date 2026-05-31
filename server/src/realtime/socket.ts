import { Server, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { redisPub, redisSub } from '../db/redis';
import { verifyAccessToken, isTokenBlacklisted } from '../services/jwt';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';
import { logger } from '../services/logger';
import { sanitizeText } from '../utils/validate';

let _io: Server | null = null;
export function getIO(): Server {
  if (!_io) throw new Error('Socket.IO not initialized');
  return _io;
}

export function applyRedisAdapter(io: Server): void {
  _io = io;
  io.adapter(createAdapter(redisPub, redisSub));
  logger.info('[Socket] Redis adapter attached — multi-node ready');
}

// Redis-backed rate limiter for socket events — survives server restarts and works across cluster nodes
async function socketRateLimit(uid: string, event: string, maxPerWindow: number, windowMs: number): Promise<boolean> {
  const key = `rl:socket:${uid}:${event}`;
  const windowSec = Math.ceil(windowMs / 1000);
  try {
    const current = await redisPub.incr(key);
    if (current === 1) await redisPub.expire(key, windowSec);
    return current <= maxPerWindow;
  } catch {
    // If Redis is unavailable, allow the request (availability > rate limiting)
    return true;
  }
}

export function setupSocket(io: Server): void {
  // JWT auth middleware — verifies signature, requires jti, and checks blacklist
  io.use(async (socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) { next(new Error('Authentication required')); return; }
    try {
      const payload = verifyAccessToken(token);
      if (!payload.jti) { next(new Error('Invalid token')); return; }
      const blacklisted = await isTokenBlacklisted(payload.jti).catch(() => false);
      if (blacklisted) { next(new Error('Token revoked')); return; }
      (socket as any).uid = payload.uid;
      (socket as any).jti = payload.jti;
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
        if (!await socketRateLimit(uid, 'chat:send', 20, 60_000)) {
          socket.emit('chat:error', { chatId, code: 'RATE_LIMITED', message: 'Slow down a moment' });
          return; // 20 messages/min
        }
        if (!text || typeof text !== 'string' || text.trim().length === 0 || text.length > 2000) return;
        const safeText = sanitizeText(text.trim());
        if (!safeText) return;
        const chat = await prisma.chat.findUnique({ where: { id: chatId } });
        if (!chat || !chat.members.includes(uid)) return;

        // Idempotency: if this exact clientMsgId was already persisted (retry
        // after a lost ACK), re-ACK the existing row instead of duplicating.
        if (clientMsgId) {
          const existing = await prisma.message.findUnique({
            where: { chatId_senderUid_clientMsgId: { chatId, senderUid: uid, clientMsgId } },
          }).catch(() => null);
          if (existing) {
            socket.emit('chat:ack', { clientMsgId, messageId: existing.id, status: existing.status });
            return;
          }
        }

        // Block check — reject sends if either party has blocked the other.
        // The chat stays intact (so history is preserved), but new messages are
        // silently dropped from the sender's side.
        const otherUids = chat.members.filter((m) => m !== uid);
        if (otherUids.length > 0) {
          const block = await prisma.block.findFirst({
            where: { OR: [
              { blockerUid: uid, blockedUid: { in: otherUids } },
              { blockedUid: uid, blockerUid: { in: otherUids } },
            ] },
          });
          if (block) {
            socket.emit('chat:error', { chatId, code: 'BLOCKED', message: 'Cannot message this user' });
            return;
          }
        }

        const message = await prisma.message.create({
          data: { chatId, senderUid: uid, text: safeText, status: 'sent', clientMsgId: clientMsgId ?? null },
        });

        await prisma.chat.update({ where: { id: chatId }, data: { updatedAt: new Date() } });

        // ACK back to sender: server received + stored
        socket.emit('chat:ack', { clientMsgId, messageId: message.id, status: 'sent' });

        // Broadcast to all members
        for (const member of chat.members) {
          io.to(`user:${member}`).emit('chat:message', { chatId, message });
        }

        // Handle delivery status + push for other members (batch-fetch first)
        const otherMembers = chat.members.filter((m) => m !== uid);
        if (otherMembers.length > 0) {
          const [users, senderProfile] = await Promise.all([
            prisma.user.findMany({ where: { id: { in: otherMembers } } }),
            prisma.profile.findUnique({ where: { userId: uid } }),
          ]);

          let anyOnline = false;
          for (const member of otherMembers) {
            const room = `user:${member}`;
            const memberSockets = await io.in(room).fetchSockets();
            if (memberSockets.length > 0) {
              anyOnline = true;
            } else {
              // Recipient offline — send push
              const recipientUser = users.find((u) => u.id === member);
              if (recipientUser?.fcmToken) {
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

          if (anyOnline) {
            await prisma.message.update({
              where: { id: message.id },
              data: { status: 'delivered', deliveredAt: new Date() },
            });
            socket.emit('chat:ack', { messageId: message.id, status: 'delivered' });
            for (const member of otherMembers) {
              io.to(`user:${member}`).emit('chat:status', { chatId, messageId: message.id, status: 'delivered' });
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

        // Verify message belongs to this chat
        const existing = await prisma.message.findUnique({ where: { id: messageId } });
        if (!existing || existing.chatId !== chatId) return;

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
      // Debounce: only write to DB once per minute per user — prevents 330+ writes/sec at scale
      if (!await socketRateLimit(uid, 'presence:ping', 1, 60_000)) return;
      await prisma.user.update({ where: { id: uid }, data: { lastActiveAt: new Date() } }).catch(() => {});
    });

    // ── BLINDS: REVEAL ──────────────────────────────────────────────────────

    socket.on('blind:reveal', async ({ sessionId }: { sessionId: string }) => {
      try {
        if (!await socketRateLimit(uid, 'blind:reveal', 5, 60_000)) return;
        const session = await prisma.blindsSession.findUnique({ where: { id: sessionId } });
        if (!session || session.phase === 'ended') return;
        if (session.userA !== uid && session.userB !== uid) return;

        // Block check — reveal must not force a blocked user to be revealed.
        const otherUid = session.userA === uid ? session.userB : session.userA;
        const block = await prisma.block.findFirst({
          where: { OR: [
            { blockerUid: uid, blockedUid: otherUid },
            { blockerUid: otherUid, blockedUid: uid },
          ] },
        });
        if (block) {
          socket.emit('blind:error', { sessionId, code: 'BLOCKED' });
          return;
        }

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
        if (!await socketRateLimit(uid, 'freeze_room:join', 10, 60_000)) return;
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
