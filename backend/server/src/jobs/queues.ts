import { Queue, Worker, Job } from 'bullmq';
import { redis } from '../db/redis';
import { prisma } from '../db/client';
import { sendPushNotification } from '../services/fcm';
import { logger } from '../services/logger';

const connection = { host: '127.0.0.1', port: 6379 };

// ── Queue definitions ────────────────────────────────────────────────────────

export const expiryQueue = new Queue('expiry', { connection });
export const pushQueue = new Queue('push', { connection });
export const cleanupQueue = new Queue('cleanup', { connection });

// ── Expiry worker — melt sessions, blind sessions, memberships ───────────────

new Worker(
  'expiry',
  async (job: Job) => {
    const { type } = job.data;

    if (type === 'melt_session') {
      const { sessionId } = job.data;
      await prisma.meltSession.updateMany({
        where: { id: sessionId, status: 'pending', expiresAt: { lt: new Date() } },
        data: { status: 'expired' },
      });
      logger.info({ msg: 'melt_session expired', sessionId });
    }

    if (type === 'blind_session') {
      const { sessionId } = job.data;
      await prisma.blindsSession.updateMany({
        where: { id: sessionId, phase: { not: 'ended' }, expiresAt: { lt: new Date() } },
        data: { phase: 'ended' },
      });
      logger.info({ msg: 'blind_session expired', sessionId });
    }

    if (type === 'membership') {
      const { userId } = job.data;
      const membership = await prisma.membership.findUnique({ where: { userId } });
      if (membership?.expiry && membership.expiry < new Date()) {
        await prisma.membership.update({ where: { userId }, data: { active: false } });
        await prisma.profile.update({ where: { userId }, data: { isPremium: false } });
        logger.info({ msg: 'membership expired', userId });
      }
    }

    if (type === 'blinds_queue_cleanup') {
      const deleted = await prisma.blindsQueue.deleteMany({
        where: { availableUntil: { lt: new Date() } },
      });
      logger.info({ msg: 'blinds_queue cleaned', count: deleted.count });
    }
  },
  { connection, concurrency: 5 }
);

// ── Push worker — reliable push with retry ───────────────────────────────────

new Worker(
  'push',
  async (job: Job) => {
    const { fcmToken, title, body, data } = job.data;
    await sendPushNotification(fcmToken, title, body, data);
    logger.info({ msg: 'push_sent', title });
  },
  {
    connection,
    concurrency: 10,
  }
);

// ── Cleanup worker — prune old data ─────────────────────────────────────────

new Worker(
  'cleanup',
  async (job: Job) => {
    const { type } = job.data;

    if (type === 'expired_tokens') {
      const deleted = await prisma.refreshToken.deleteMany({
        where: { expiresAt: { lt: new Date() } },
      });
      logger.info({ msg: 'expired_tokens_pruned', count: deleted.count });
    }

    if (type === 'old_messages') {
      // Archive messages older than 90 days
      const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
      const deleted = await prisma.message.deleteMany({
        where: { createdAt: { lt: cutoff } },
      });
      logger.info({ msg: 'old_messages_pruned', count: deleted.count });
    }
  },
  { connection }
);

// ── Scheduled recurring jobs ─────────────────────────────────────────────────

export async function scheduleRecurringJobs(): Promise<void> {
  // Prune expired refresh tokens — every hour
  await cleanupQueue.add(
    'expired_tokens',
    { type: 'expired_tokens' },
    { repeat: { every: 60 * 60 * 1000 }, jobId: 'expired_tokens_hourly' }
  );

  // Clean blinds queue — every 15 minutes
  await expiryQueue.add(
    'blinds_queue_cleanup',
    { type: 'blinds_queue_cleanup' },
    { repeat: { every: 15 * 60 * 1000 }, jobId: 'blinds_queue_cleanup' }
  );

  // Prune old messages — daily at midnight
  await cleanupQueue.add(
    'old_messages',
    { type: 'old_messages' },
    { repeat: { every: 24 * 60 * 60 * 1000 }, jobId: 'old_messages_daily' }
  );

  logger.info('[Jobs] recurring jobs scheduled');
}

// ── Helper: schedule expiry for a melt session ───────────────────────────────

export async function scheduleMeltExpiry(sessionId: string, expiresAt: Date): Promise<void> {
  const delay = Math.max(0, expiresAt.getTime() - Date.now());
  await expiryQueue.add(
    'melt_session',
    { type: 'melt_session', sessionId },
    { delay, jobId: `melt_expire_${sessionId}`, attempts: 3, backoff: { type: 'exponential', delay: 5000 } }
  );
}

export async function scheduleBlindExpiry(sessionId: string, expiresAt: Date): Promise<void> {
  const delay = Math.max(0, expiresAt.getTime() - Date.now());
  await expiryQueue.add(
    'blind_session',
    { type: 'blind_session', sessionId },
    { delay, jobId: `blind_expire_${sessionId}`, attempts: 3, backoff: { type: 'exponential', delay: 5000 } }
  );
}

export async function scheduleMembershipExpiry(userId: string, expiresAt: Date): Promise<void> {
  const delay = Math.max(0, expiresAt.getTime() - Date.now());
  await expiryQueue.add(
    'membership',
    { type: 'membership', userId },
    { delay, jobId: `membership_expire_${userId}`, attempts: 3, backoff: { type: 'exponential', delay: 10000 } }
  );
}

export async function enqueuePush(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  await pushQueue.add(
    'push',
    { fcmToken, title, body, data },
    { attempts: 3, backoff: { type: 'exponential', delay: 3000 } }
  );
}
