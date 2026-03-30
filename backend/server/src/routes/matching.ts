import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';

const router = Router();
router.use(requireAuth);

// POST /matching/like — replaces likeProfile Cloud Function
router.post('/like', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.body;
    if (!targetUid) { res.status(400).json({ error: 'targetUid required' }); return; }
    if (targetUid === req.uid) { res.status(400).json({ error: 'Cannot like yourself' }); return; }

    // Idempotent upsert
    await prisma.like.upsert({
      where: { senderUid_targetUid: { senderUid: req.uid, targetUid } },
      update: {},
      create: { senderUid: req.uid, targetUid },
    });

    // Check for mutual like → create match
    const mutual = await prisma.like.findUnique({
      where: { senderUid_targetUid: { senderUid: targetUid, targetUid: req.uid } },
    });

    let match = null;
    if (mutual) {
      // Check no existing active match
      const existing = await prisma.match.findFirst({
        where: { members: { hasEvery: [req.uid, targetUid] }, status: 'active' },
      });

      if (!existing) {
        match = await prisma.match.create({
          data: { members: [req.uid, targetUid] },
        });

        // Create initial chat
        await prisma.chat.create({
          data: { members: [req.uid, targetUid], matchId: match.id },
        });

        // Push notification to the other user
        const [myProfile, theirUser] = await Promise.all([
          prisma.profile.findUnique({ where: { userId: req.uid } }),
          prisma.user.findUnique({ where: { id: targetUid } }),
        ]);

        if (theirUser?.fcmToken && myProfile?.name) {
          await enqueuePush(
            theirUser.fcmToken,
            "It's a Match!",
            `You and ${myProfile.name} liked each other.`,
            { type: 'match', matchId: match.id }
          );
        }
      }
    }

    res.json({ liked: true, match });
  } catch (err) {
    console.error('[matching/like]', err);
    res.status(500).json({ error: 'Failed to register like' });
  }
});

// POST /matching/skip — replaces skipProfile Cloud Function
router.post('/skip', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.body;
    if (!targetUid) { res.status(400).json({ error: 'targetUid required' }); return; }

    await prisma.skip.upsert({
      where: { senderUid_targetUid: { senderUid: req.uid, targetUid } },
      update: {},
      create: { senderUid: req.uid, targetUid },
    });

    res.json({ skipped: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to register skip' });
  }
});

// GET /matching/matches — replaces getMatches Cloud Function
router.get('/matches', async (req: Request, res: Response) => {
  try {
    const matches = await prisma.match.findMany({
      where: { members: { has: req.uid }, status: 'active' },
      orderBy: { createdAt: 'desc' },
    });

    // Enrich with other user's profile
    const enriched = await Promise.all(
      matches.map(async (m) => {
        const otherUid = m.members.find((id) => id !== req.uid)!;
        const profile = await prisma.profile.findUnique({ where: { userId: otherUid } });
        return { ...m, otherProfile: profile };
      })
    );

    res.json(enriched);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch matches' });
  }
});

export default router;
