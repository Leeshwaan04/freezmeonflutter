import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { scheduleBlindExpiry, enqueuePush } from '../jobs/queues';
import { io } from '../index';
import { isValidBlindIntent, isValidDistanceBucket, isValidInterests } from '../utils/validate';
import { logger } from '../services/logger';

const router = Router();
router.use(requireAuth);

const BLIND_SESSION_MINUTES = 12;
const DAILY_ENQUEUE_LIMIT = 5;

// POST /blinds/enqueue — replaces enqueueBlind Cloud Function
router.post('/enqueue', async (req: Request, res: Response) => {
  try {
    const { intent, distanceBucket, interests } = req.body;
    if (!intent || !distanceBucket) {
      res.status(400).json({ code: 'MISSING_FIELD', error: 'intent and distanceBucket required' }); return;
    }

    // Daily rate limit: max DAILY_ENQUEUE_LIMIT blind sessions per user per UTC day
    const dayStart = new Date();
    dayStart.setUTCHours(0, 0, 0, 0);
    const todayCount = await prisma.blindsSession.count({
      where: {
        OR: [{ userA: req.uid }, { userB: req.uid }],
        createdAt: { gte: dayStart },
      },
    });
    if (todayCount >= DAILY_ENQUEUE_LIMIT) {
      res.status(429).json({ code: 'DAILY_LIMIT_REACHED', error: `You can start up to ${DAILY_ENQUEUE_LIMIT} blind sessions per day. Come back tomorrow!` });
      return;
    }
    if (!isValidBlindIntent(intent)) {
      res.status(400).json({ code: 'INVALID_INTENT', error: 'intent must be one of: friends, dates, either' }); return;
    }
    if (!isValidDistanceBucket(distanceBucket)) {
      res.status(400).json({ code: 'INVALID_DISTANCE_BUCKET', error: 'Invalid distanceBucket value' }); return;
    }
    if (interests !== undefined && !isValidInterests(interests)) {
      res.status(400).json({ code: 'INVALID_INTERESTS', error: 'interests must be an array of at most 30 strings' }); return;
    }

    const availableUntil = new Date(Date.now() + 30 * 60 * 1000); // 30 min

    const entry = await prisma.blindsQueue.upsert({
      where: { uid: req.uid },
      update: { intent, distanceBucket, interests: interests ?? [], availableUntil },
      create: { uid: req.uid, intent, distanceBucket, interests: interests ?? [], availableUntil },
    });

    // Find UIDs the current user has already had a blind session with (avoid re-matching)
    const priorSessions = await prisma.blindsSession.findMany({
      where: { OR: [{ userA: req.uid }, { userB: req.uid }] },
      select: { userA: true, userB: true },
    });
    const priorMatchedUids = new Set<string>(
      priorSessions.flatMap((s) => [s.userA, s.userB]).filter((u) => u !== req.uid)
    );

    // Also exclude existing Match partners (already connected via regular matching)
    const existingMatches = await prisma.match.findMany({
      where: { members: { has: req.uid }, status: 'active' },
      select: { members: true },
    });
    for (const m of existingMatches) {
      m.members.filter((u) => u !== req.uid).forEach((u) => priorMatchedUids.add(u));
    }

    // Try to find a match — exclude self + prior sessions + existing matches
    const match = await prisma.blindsQueue.findFirst({
      where: {
        uid: { not: req.uid, notIn: [...priorMatchedUids] },
        intent,
        distanceBucket,
        availableUntil: { gt: new Date() },
      },
    });

    if (match) {
      // Remove both from queue and create session atomically
      const session = await prisma.$transaction(async (tx) => {
        // Double-check the match candidate is still in queue
        const candidate = await tx.blindsQueue.findUnique({ where: { uid: match.uid } });
        if (!candidate) return null;

        await tx.blindsQueue.deleteMany({ where: { uid: { in: [req.uid, match.uid] } } });

        const expiresAt = new Date(Date.now() + BLIND_SESSION_MINUTES * 60 * 1000);
        return tx.blindsSession.create({
          data: { userA: req.uid, userB: match.uid, expiresAt },
        });
      });

      if (!session) {
        // Candidate was taken by another concurrent request — stay queued
        res.json({ queued: true, entry });
        return;
      }

      // Schedule expiry job
      await scheduleBlindExpiry(session.id, session.expiresAt).catch(() => {});

      // Notify both users via WebSocket
      io.to(`user:${req.uid}`).emit('blind:session_created', { session });
      io.to(`user:${match.uid}`).emit('blind:session_created', { session });

      // Push notifications
      const [myUser, theirUser] = await Promise.all([
        prisma.user.findUnique({ where: { id: req.uid } }),
        prisma.user.findUnique({ where: { id: match.uid } }),
      ]);
      if (theirUser?.fcmToken) {
        await enqueuePush(
          theirUser.fcmToken,
          'Blind Session Started',
          'Someone nearby wants to connect anonymously!',
          { type: 'blind_session', sessionId: session.id }
        ).catch(() => {});
      }
      if (myUser?.fcmToken) {
        await enqueuePush(
          myUser.fcmToken,
          'Blind Session Started',
          'You\'ve been matched anonymously — say hello!',
          { type: 'blind_session', sessionId: session.id }
        ).catch(() => {});
      }

      res.json({ queued: false, session });
    } else {
      res.json({ queued: true, entry });
    }
  } catch (err) {
    logger.error({ msg: 'blinds_enqueue_error', err });
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to enqueue' });
  }
});

// DELETE /blinds/enqueue — replaces dequeueBlind Cloud Function
router.delete('/enqueue', async (req: Request, res: Response) => {
  try {
    await prisma.blindsQueue.deleteMany({ where: { uid: req.uid } });
    res.json({ dequeued: true });
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to dequeue' });
  }
});

// GET /blinds/session — get active session for user
router.get('/session', async (req: Request, res: Response) => {
  try {
    const session = await prisma.blindsSession.findFirst({
      where: {
        OR: [{ userA: req.uid }, { userB: req.uid }],
        phase: { not: 'ended' },
        expiresAt: { gt: new Date() },
      },
      orderBy: { expiresAt: 'desc' },
    });
    res.json(session);
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch blind session' });
  }
});

// POST /blinds/session/:id/reveal — reveal identity
router.post('/session/:id/reveal', async (req: Request, res: Response) => {
  try {
    // Use atomic updateMany with a where-clause guard so concurrent reveals are idempotent
    const session = await prisma.blindsSession.findUnique({ where: { id: req.params.id } });
    if (!session) { res.status(404).json({ code: 'NOT_FOUND', error: 'Session not found' }); return; }
    if (session.userA !== req.uid && session.userB !== req.uid) {
      res.status(403).json({ code: 'FORBIDDEN', error: 'Access denied' }); return;
    }
    if (session.phase === 'ended') {
      res.status(400).json({ code: 'SESSION_ENDED', error: 'Session has already ended' }); return;
    }

    const isUserA = session.userA === req.uid;
    // Only update if reveal not already set (prevents double-write on concurrent calls)
    const updated = await prisma.blindsSession.update({
      where: { id: req.params.id, ...(isUserA ? { revealA: false } : { revealB: false }) },
      data: isUserA ? { revealA: true } : { revealB: true },
    }).catch(() => prisma.blindsSession.findUnique({ where: { id: req.params.id } }));

    if (!updated) { res.status(404).json({ code: 'NOT_FOUND', error: 'Session not found' }); return; }

    // Emit real-time phase change to both parties
    io.to(`user:${session.userA}`).emit('blind:phase_change', { sessionId: session.id, session: updated });
    io.to(`user:${session.userB}`).emit('blind:phase_change', { sessionId: session.id, session: updated });

    res.json(updated);
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to reveal' });
  }
});

// POST /blinds/session/:id/report — replaces reportBlindSession Cloud Function
router.post('/session/:id/report', async (req: Request, res: Response) => {
  try {
    const { reason } = req.body;
    const session = await prisma.blindsSession.findUnique({ where: { id: req.params.id } });
    if (!session) { res.status(404).json({ code: 'NOT_FOUND', error: 'Session not found' }); return; }
    if (session.userA !== req.uid && session.userB !== req.uid) {
      res.status(403).json({ code: 'FORBIDDEN', error: 'Access denied' }); return;
    }

    await prisma.blindsSession.update({
      where: { id: req.params.id },
      data: { reported: true, reportReason: reason, phase: 'ended' },
    });

    res.json({ reported: true });
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to report session' });
  }
});

export default router;
