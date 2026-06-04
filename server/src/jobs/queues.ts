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

    if (type === 'expired_matches') {
      // Find matches older than 7 days that have NO messages sent in their chat.
      const cutoff = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
      const staleMatches = await prisma.match.findMany({
        where: {
          status: 'active',
          createdAt: { lt: cutoff },
          chats: {
            some: {
              messages: {
                none: {} // True if no messages exist
              }
            }
          }
        },
        include: { chats: true }
      });

      if (staleMatches.length > 0) {
        let totalExpired = 0;
        for (const match of staleMatches) {
          await prisma.$transaction(async (tx) => {
            await tx.match.update({ where: { id: match.id }, data: { status: 'expired' } });
            await tx.chat.deleteMany({ where: { matchId: match.id } });
            if (match.members.length === 2) {
              await tx.like.deleteMany({
                where: {
                  OR: [
                    { senderUid: match.members[0], targetUid: match.members[1] },
                    { senderUid: match.members[1], targetUid: match.members[0] },
                  ]
                }
              });
            }
          });
          totalExpired++;
        }
        logger.info({ msg: 'expired_matches_pruned', count: totalExpired });
      }
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

    // Sweep ALL expired subscriptions — revoke premium when membership.expiry
    // has passed. This is the safety net behind Apple Server Notifications:
    // even if a webhook is missed, premium is revoked within the sweep interval.
    if (type === 'expire_subscriptions') {
      const now = new Date();
      const expired = await prisma.membership.findMany({
        where: { active: true, expiry: { lt: now } },
        select: { userId: true },
      });
      if (expired.length > 0) {
        const uids = expired.map((m) => m.userId);
        await prisma.$transaction([
          prisma.membership.updateMany({ where: { userId: { in: uids } }, data: { active: false } }),
          prisma.profile.updateMany({ where: { userId: { in: uids } }, data: { isPremium: false } }),
        ]);
      }
      logger.info({ msg: 'expire_subscriptions_swept', count: expired.length });
    }

    // GDPR: permanently purge accounts that were soft-deleted (status='deleted')
    // more than 30 days ago. Until then the user can still recover by logging in.
    if (type === 'purge_deleted_accounts') {
      const cutoff = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
      const toPurge = await prisma.user.findMany({
        where: { status: 'deleted', lastActiveAt: { lt: cutoff } },
        select: { id: true, selfieKey: true },
      });
      let purged = 0;
      for (const u of toPurge) {
        const uid = u.id;
        try {
          // Collect S3 keys (profile photo, feed photos, selfie) before deletion
          const s3Keys: string[] = [];
          if (u.selfieKey) s3Keys.push(u.selfieKey);
          const [profile, feedPosts] = await Promise.all([
            prisma.profile.findUnique({ where: { userId: uid }, select: { imageUrl: true } }),
            prisma.feedPost.findMany({ where: { authorUid: uid }, select: { photoUrls: true } }),
          ]);
          const extractKey = (url: string): string | null => {
            try {
              const p = new URL(url).pathname.replace(/^\//, '');
              return p.startsWith('uploads/') ? p : null;
            } catch { return null; }
          };
          if (profile?.imageUrl) { const k = extractKey(profile.imageUrl); if (k) s3Keys.push(k); }
          for (const post of feedPosts) for (const url of post.photoUrls) { const k = extractKey(url); if (k) s3Keys.push(k); }

          await prisma.$transaction(async (tx) => {
            await tx.like.deleteMany({ where: { OR: [{ senderUid: uid }, { targetUid: uid }] } });
            await tx.skip.deleteMany({ where: { OR: [{ senderUid: uid }, { targetUid: uid }] } });
            await tx.pathInvite.deleteMany({ where: { OR: [{ senderUid: uid }, { receiverUid: uid }] } });
            await tx.blindsQueue.deleteMany({ where: { uid } });
            await tx.meltSession.deleteMany({ where: { OR: [{ hostUid: uid }, { targetUid: uid }] } });
            await tx.pathsPresence.deleteMany({ where: { uid } });
            await tx.presenceEvent.deleteMany({ where: { uid } });
            await tx.feedPost.deleteMany({ where: { authorUid: uid } });
            await tx.postLike.deleteMany({ where: { uid } });
            await tx.postComment.deleteMany({ where: { authorUid: uid } });
            await tx.refreshToken.deleteMany({ where: { userId: uid } });
            await tx.freezeMatch.deleteMany({ where: { OR: [{ userA: uid }, { userB: uid }] } });
            await tx.freezeRoomParticipant.deleteMany({ where: { uid } });
            await tx.block.deleteMany({ where: { OR: [{ blockerUid: uid }, { blockedUid: uid }] } });
            // eslint-disable-next-line @typescript-eslint/no-explicit-any
            await (tx as any).report.deleteMany({ where: { OR: [{ reporterUid: uid }, { reportedUid: uid }] } }).catch(() => {});
            await tx.passwordResetToken.deleteMany({ where: { userId: uid } });
            await tx.emailVerificationToken.deleteMany({ where: { userId: uid } });
            const chats = await tx.chat.findMany({ where: { members: { has: uid } }, select: { id: true } });
            const chatIds = chats.map((c) => c.id);
            if (chatIds.length > 0) {
              await tx.message.deleteMany({ where: { chatId: { in: chatIds } } });
              await tx.chat.deleteMany({ where: { id: { in: chatIds } } });
            }
            await tx.message.deleteMany({ where: { senderUid: uid } });
            await tx.match.deleteMany({ where: { members: { has: uid } } });
            await tx.user.delete({ where: { id: uid } }); // Profile + Membership cascade
          });
          // Fire-and-forget S3 cleanup
          if (s3Keys.length > 0) {
            // eslint-disable-next-line @typescript-eslint/no-var-requires
            const { deleteS3Object } = await import('../services/s3');
            Promise.allSettled(s3Keys.map((k) => deleteS3Object(k))).catch(() => {});
          }
          purged++;
        } catch (err) {
          logger.error({ msg: 'purge_deleted_account_failed', uid, err });
        }
      }
      logger.info({ msg: 'purge_deleted_accounts_complete', purged, candidates: toPurge.length });
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

  // Expire 7-day stale matches with no messages — daily
  await cleanupQueue.add(
    'expired_matches',
    { type: 'expired_matches' },
    { repeat: { every: 24 * 60 * 60 * 1000 }, jobId: 'expired_matches_daily' }
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

  // Sweep expired subscriptions — every hour (safety net behind Apple webhook)
  await cleanupQueue.add(
    'expire_subscriptions',
    { type: 'expire_subscriptions' },
    { repeat: { every: 60 * 60 * 1000 }, jobId: 'expire_subscriptions_hourly' }
  );

  // GDPR purge of accounts soft-deleted >30 days ago — daily
  await cleanupQueue.add(
    'purge_deleted_accounts',
    { type: 'purge_deleted_accounts' },
    { repeat: { every: 24 * 60 * 60 * 1000 }, jobId: 'purge_deleted_accounts_daily' }
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
