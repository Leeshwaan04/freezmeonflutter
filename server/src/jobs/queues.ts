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

    if (type === 'pool_reset') {
      // Close any open sessions whose closesAt has passed
      await prisma.poolSession.updateMany({
        where: { isOpen: true, closesAt: { lte: new Date() } },
        data: { isOpen: false },
      });

      // Open the session whose opensAt is now or in the past but closesAt is future
      const now = new Date();
      await prisma.poolSession.updateMany({
        where: { isOpen: false, opensAt: { lte: now }, closesAt: { gt: now } },
        data: { isOpen: true },
      });

      // Create tomorrow's session if it doesn't exist yet
      const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
      const nowIST = new Date(now.getTime() + IST_OFFSET_MS);
      const tomorrowIST = new Date(Date.UTC(
        nowIST.getUTCFullYear(), nowIST.getUTCMonth(), nowIST.getUTCDate() + 1,
      ));
      const nextOpens = new Date(tomorrowIST.getTime() + (18 * 60 - 330) * 60 * 1000);
      const nextCloses = new Date(nextOpens.getTime() + 6 * 60 * 60 * 1000);
      const existing = await prisma.poolSession.findFirst({
        where: { opensAt: nextOpens },
      });
      if (!existing) {
        await prisma.poolSession.create({
          data: { opensAt: nextOpens, closesAt: nextCloses, isOpen: false },
        });
      }
      logger.info({ msg: 'pool_reset complete', isNowOpen: true });
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
      const now = new Date();
      const [rt, bl, prt] = await Promise.all([
        prisma.refreshToken.deleteMany({ where: { expiresAt: { lt: now } } }),
        prisma.tokenBlacklist.deleteMany({ where: { expiresAt: { lt: now } } }),
        prisma.passwordResetToken.deleteMany({ where: { expiresAt: { lt: now } } }),
      ]);
      logger.info({ msg: 'expired_tokens_pruned', refreshTokens: rt.count, blacklist: bl.count, passwordResetTokens: prt.count });
    }

    if (type === 'old_messages') {
      const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
      // Batch deletes to avoid locking the table for large datasets
      let totalDeleted = 0;
      for (let i = 0; i < 200; i++) {
        const ids = await prisma.message.findMany({
          where: { createdAt: { lt: cutoff } },
          select: { id: true },
          take: 5_000,
        });
        if (ids.length === 0) break;
        const batch = await prisma.message.deleteMany({
          where: { id: { in: ids.map(r => r.id) } },
        });
        totalDeleted += batch.count;
        // Small pause between batches to reduce DB pressure
        await new Promise(r => setTimeout(r, 50));
      }
      logger.info({ msg: 'old_messages_pruned', count: totalDeleted });
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

    if (type === 'old_presence_events') {
      // Keep 90 days of presence data for scoring; prune the rest
      const cutoff = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
      const deleted = await prisma.presenceEvent.deleteMany({
        where: { createdAt: { lt: cutoff } },
      });
      logger.info({ msg: 'old_presence_events_pruned', count: deleted.count });
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

    // Recompute presence scores for all profiles — bulk SQL (O(1) queries vs O(U×4))
    if (type === 'presence_score_update') {
      // Single UPDATE using correlated subqueries — replaces per-user loop
      await prisma.$executeRaw`
        UPDATE "Profile" p
        SET
          "presenceScore" = LEAST(100, ROUND(
            -- Activity frequency: up to 40 pts (1 event/day = full)
            LEAST(
              (SELECT COUNT(*) FROM "PresenceEvent"
               WHERE uid = p."userId"
               AND "createdAt" >= NOW() - INTERVAL '30 days') / 30.0, 1
            ) * 40
            +
            -- Recency: up to 30 pts (active last 7 days)
            LEAST(
              (SELECT COUNT(*) FROM "PresenceEvent"
               WHERE uid = p."userId"
               AND "createdAt" >= NOW() - INTERVAL '7 days') / 7.0, 1
            ) * 30
            +
            -- Conversation depth: up to 30 pts (10 messages sent in 7d = full)
            LEAST(
              (SELECT COUNT(*) FROM "Message"
               WHERE "senderUid" = p."userId"
               AND "createdAt" >= NOW() - INTERVAL '7 days') / 10.0, 1
            ) * 30
          )::int),
          "presenceLabel" = CASE
            WHEN LEAST(100, ROUND(
              LEAST((SELECT COUNT(*) FROM "PresenceEvent" WHERE uid = p."userId" AND "createdAt" >= NOW() - INTERVAL '30 days') / 30.0, 1) * 40
              + LEAST((SELECT COUNT(*) FROM "PresenceEvent" WHERE uid = p."userId" AND "createdAt" >= NOW() - INTERVAL '7 days') / 7.0, 1) * 30
              + LEAST((SELECT COUNT(*) FROM "Message" WHERE "senderUid" = p."userId" AND "createdAt" >= NOW() - INTERVAL '7 days') / 10.0, 1) * 30
            )::int) >= 80 THEN 'in_the_fire'
            WHEN LEAST(100, ROUND(
              LEAST((SELECT COUNT(*) FROM "PresenceEvent" WHERE uid = p."userId" AND "createdAt" >= NOW() - INTERVAL '30 days') / 30.0, 1) * 40
              + LEAST((SELECT COUNT(*) FROM "PresenceEvent" WHERE uid = p."userId" AND "createdAt" >= NOW() - INTERVAL '7 days') / 7.0, 1) * 30
              + LEAST((SELECT COUNT(*) FROM "Message" WHERE "senderUid" = p."userId" AND "createdAt" >= NOW() - INTERVAL '7 days') / 10.0, 1) * 30
            )::int) >= 50 THEN 'in_the_flow'
            WHEN LEAST(100, ROUND(
              LEAST((SELECT COUNT(*) FROM "PresenceEvent" WHERE uid = p."userId" AND "createdAt" >= NOW() - INTERVAL '30 days') / 30.0, 1) * 40
              + LEAST((SELECT COUNT(*) FROM "PresenceEvent" WHERE uid = p."userId" AND "createdAt" >= NOW() - INTERVAL '7 days') / 7.0, 1) * 30
              + LEAST((SELECT COUNT(*) FROM "Message" WHERE "senderUid" = p."userId" AND "createdAt" >= NOW() - INTERVAL '7 days') / 10.0, 1) * 30
            )::int) >= 20 THEN 'in_the_quiet'
            ELSE 'frozen'
          END
      `;

      const count = await prisma.profile.count();
      logger.info({ msg: 'presence_scores_updated', count });
    }
  },
  { connection, concurrency: 1 }  // Only one cleanup job at a time to avoid DB overload
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

  // Prune PresenceEvents older than 90 days — weekly
  await cleanupQueue.add(
    'old_presence_events',
    { type: 'old_presence_events' },
    { repeat: { every: 7 * 24 * 60 * 60 * 1000 }, jobId: 'old_presence_events_weekly' }
  );

  // Open first room immediately on startup
  await cleanupQueue.add('freeze_room_open', { type: 'freeze_room_open' }, { jobId: 'freeze_room_open_boot' });

  // Pool reset — runs every 30 minutes to open/close sessions and pre-create next day's
  await expiryQueue.add(
    'pool_reset',
    { type: 'pool_reset' },
    { repeat: { every: 30 * 60 * 1000 }, jobId: 'pool_reset_30min' }
  );

  // Run pool reset immediately on startup
  await expiryQueue.add('pool_reset', { type: 'pool_reset' }, { jobId: 'pool_reset_boot' });

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
