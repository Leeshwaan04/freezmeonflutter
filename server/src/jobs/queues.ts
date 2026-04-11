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
      const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
      const deleted = await prisma.message.deleteMany({ where: { createdAt: { lt: cutoff } } });
      logger.info({ msg: 'old_messages_pruned', count: deleted.count });
    }

    if (type === 'expired_path_invites') {
      const deleted = await prisma.pathInvite.deleteMany({
        where: { status: 'pending', expiresAt: { lt: new Date() } },
      });
      logger.info({ msg: 'expired_path_invites_pruned', count: deleted.count });
    }

    if (type === 'old_blind_sessions') {
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const deleted = await prisma.blindsSession.deleteMany({
        where: { phase: 'ended', expiresAt: { lt: cutoff } },
      });
      logger.info({ msg: 'old_blind_sessions_pruned', count: deleted.count });
    }

    // Open a new Freeze Room (rolls every 2 hours)
    if (type === 'freeze_room_open') {
      const types: Array<'reflective' | 'playful' | 'values'> = ['reflective', 'playful', 'values'];
      const promptType = types[Math.floor(Date.now() / (2 * 60 * 60 * 1000)) % 3];
      const promptBanks: Record<string, string[]> = {
        reflective: [
          'The best decision you ever made — describe it in one sentence.',
          'Something you changed your mind about completely in the last year.',
          'A moment you felt most like yourself.',
          'The thing you wish you had done sooner.',
        ],
        playful: [
          "You're planning the perfect Sunday for two strangers. What happens?",
          'The most chaotic thing you\'ve done that turned out perfectly.',
          'Describe your ideal morning using only three words.',
          'The last thing that made you laugh until it hurt.',
        ],
        values: [
          'The one thing you\'d never compromise on.',
          'What does a good day look like to you?',
          'Something you believe that most people around you don\'t.',
          'What you\'re most proud of that nobody gave you an award for.',
        ],
      };
      const list = promptBanks[promptType];
      const prompt = list[Math.floor(Math.random() * list.length)];
      const now = new Date();
      const closesAt = new Date(now.getTime() + 20 * 60 * 1000); // 20 minutes
      const room = await prisma.freezeRoom.create({
        data: { promptType, prompt, closesAt, status: 'open' },
      });
      logger.info({ msg: 'freeze_room_opened', roomId: room.id, promptType, prompt });
    }

    // Close expired Freeze Rooms
    if (type === 'freeze_room_close') {
      const closed = await prisma.freezeRoom.updateMany({
        where: { status: 'open', closesAt: { lt: new Date() } },
        data: { status: 'closed' },
      });
      if (closed.count > 0) logger.info({ msg: 'freeze_rooms_closed', count: closed.count });
    }

    // Recompute presence scores for all profiles
    if (type === 'presence_score_update') {
      const cutoff30d = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const cutoff7d  = new Date(Date.now() - 7  * 24 * 60 * 60 * 1000);

      const profiles = await prisma.profile.findMany({ select: { userId: true } });

      for (const p of profiles) {
        const [events30d, events7d, messagesSent7d, matchesResponded7d] = await Promise.all([
          prisma.presenceEvent.count({ where: { uid: p.userId, createdAt: { gte: cutoff30d } } }),
          prisma.presenceEvent.count({ where: { uid: p.userId, createdAt: { gte: cutoff7d } } }),
          prisma.message.count({ where: { senderUid: p.userId, createdAt: { gte: cutoff7d } } }),
          prisma.message.count({
            where: {
              senderUid: p.userId,
              createdAt: { gte: cutoff7d },
              chat: { messages: { some: { senderUid: { not: p.userId } } } },
            },
          }),
        ]);

        // Score: activity frequency (40) + recency (30) + conversation depth (30)
        const activityScore  = Math.min(events30d / 30, 1) * 40;   // 1 event/day = full score
        const recencyScore   = Math.min(events7d / 7, 1) * 30;     // active last 7d
        const depthScore     = Math.min((messagesSent7d + matchesResponded7d) / 10, 1) * 30;

        const presenceScore  = Math.round(activityScore + recencyScore + depthScore);

        const presenceLabel  = presenceScore >= 80 ? 'in_the_fire'
          : presenceScore >= 50 ? 'in_the_flow'
          : presenceScore >= 20 ? 'in_the_quiet'
          : 'frozen';

        await prisma.profile.update({
          where: { userId: p.userId },
          data: { presenceScore, presenceLabel },
        });
      }

      logger.info({ msg: 'presence_scores_updated', count: profiles.length });
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

  // Open a new Freeze Room every 2 hours
  await cleanupQueue.add(
    'freeze_room_open',
    { type: 'freeze_room_open' },
    { repeat: { every: 2 * 60 * 60 * 1000 }, jobId: 'freeze_room_open' }
  );

  // Close expired Freeze Rooms — every 5 minutes
  await cleanupQueue.add(
    'freeze_room_close',
    { type: 'freeze_room_close' },
    { repeat: { every: 5 * 60 * 1000 }, jobId: 'freeze_room_close' }
  );

  // Recompute presence scores — every 6 hours
  await cleanupQueue.add(
    'presence_score_update',
    { type: 'presence_score_update' },
    { repeat: { every: 6 * 60 * 60 * 1000 }, jobId: 'presence_score_update' }
  );

  // Clean up expired PathInvites — every hour
  await cleanupQueue.add(
    'expired_path_invites',
    { type: 'expired_path_invites' },
    { repeat: { every: 60 * 60 * 1000 }, jobId: 'expired_path_invites_hourly' }
  );

  // Clean up ended BlindSessions older than 7 days — daily
  await cleanupQueue.add(
    'old_blind_sessions',
    { type: 'old_blind_sessions' },
    { repeat: { every: 24 * 60 * 60 * 1000 }, jobId: 'old_blind_sessions_daily' }
  );

  // Open first room immediately on startup
  await cleanupQueue.add('freeze_room_open', { type: 'freeze_room_open' }, { jobId: 'freeze_room_open_boot' });

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
