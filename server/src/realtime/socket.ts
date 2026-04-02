import { Server, Socket } from 'socket.io';
import { createAdapter } from '@socket.io/redis-adapter';
import { redisPub, redisSub } from '../db/redis';
import { verifyAccessToken } from '../services/jwt';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';
import { logger } from '../services/logger';

export function applyRedisAdapter(io: Server): void {
  io.adapter(createAdapter(redisPub, redisSub));
  logger.info('[Socket] Redis adapter attached — multi-node ready');
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
        const chat = await prisma.chat.findUnique({ where: { id: chatId } });
        if (!chat || !chat.members.includes(uid)) return;

        const message = await prisma.message.create({
          data: { chatId, senderUid: uid, text, status: 'sent' },
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
                await enqueuePush(
                  recipientUser.fcmToken,
                  senderProfile?.name ?? 'New message',
                  text.length > 80 ? `${text.slice(0, 80)}…` : text,
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
        const message = await prisma.message.update({
          where: { id: messageId },
          data: { status: 'read', readAt: new Date() },
        });

        const chat = await prisma.chat.findUnique({ where: { id: chatId } });
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
        const session = await prisma.blindsSession.findUnique({ where: { id: sessionId } });
        if (!session) return;
        if (session.userA !== uid && session.userB !== uid) return;

        const isA = session.userA === uid;
        const updated = await prisma.blindsSession.update({
          where: { id: sessionId },
          data: isA ? { revealA: true } : { revealB: true },
        });

        io.to(`user:${session.userA}`).emit('blind:phase_change', { sessionId, session: updated });
        io.to(`user:${session.userB}`).emit('blind:phase_change', { sessionId, session: updated });
      } catch (err) {
        logger.error({ msg: 'socket_blind_reveal_error', err });
      }
    });

    // ── DISCONNECT ──────────────────────────────────────────────────────────

    socket.on('disconnect', (reason) => {
      logger.info({ msg: 'socket_disconnected', uid, reason });
    });
  });
}
