import { Router } from 'express';
import { prisma } from '../db/client';
import { requireAuth } from '../middleware/auth';

const router = Router();

/**
 * GET /pool/session
 * Returns the current pool session state so the client can show
 * a real open/close timer instead of a hardcoded midnight countdown.
 *
 * Response:
 *   { isOpen: boolean, opensAt: ISO, closesAt: ISO }
 *
 * The pool opens at 18:00 IST and closes at 00:00 IST every day.
 * If no active PoolSession row exists we derive the next window on-the-fly
 * so the endpoint always returns something useful.
 */
router.get('/session', requireAuth, async (_req, res) => {
  try {
    const now = new Date();

    // Find the most recent session that either contains `now` or is the
    // next upcoming session.
    let session = await prisma.poolSession.findFirst({
      where: { closesAt: { gt: now } },
      orderBy: { opensAt: 'asc' },
    });

    if (!session) {
      // Derive the next session window (18:00 → 00:00 IST)
      // We store UTC in DB; IST = UTC+5:30
      const IST_OFFSET_MS = 5.5 * 60 * 60 * 1000;
      const nowIST = new Date(now.getTime() + IST_OFFSET_MS);
      const todayIST = new Date(Date.UTC(
        nowIST.getUTCFullYear(),
        nowIST.getUTCMonth(),
        nowIST.getUTCDate(),
      ));

      // Pool opens 18:00 IST = 12:30 UTC
      const opensUTC = new Date(todayIST.getTime() + (18 * 60 - 330) * 60 * 1000);
      // Pool closes 00:00 IST next day = 18:30 UTC
      const closesUTC = new Date(opensUTC.getTime() + 6 * 60 * 60 * 1000);

      // If today's open window is already past, shift to tomorrow
      const effectiveOpens = opensUTC < now
        ? new Date(opensUTC.getTime() + 24 * 60 * 60 * 1000)
        : opensUTC;
      const effectiveCloses = closesUTC < now
        ? new Date(closesUTC.getTime() + 24 * 60 * 60 * 1000)
        : closesUTC;

      session = await prisma.poolSession.create({
        data: {
          opensAt: effectiveOpens,
          closesAt: effectiveCloses,
          isOpen: now >= effectiveOpens && now < effectiveCloses,
        },
      });
    }

    const isOpen = session.isOpen && now >= session.opensAt && now < session.closesAt;

    return res.json({
      isOpen,
      opensAt: session.opensAt.toISOString(),
      closesAt: session.closesAt.toISOString(),
    });
  } catch (err) {
    return res.status(500).json({ error: 'pool_session_error' });
  }
});

export default router;
