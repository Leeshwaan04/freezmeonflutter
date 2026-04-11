import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';
import { io } from '../index';

const router = Router();
router.use(requireAuth);

// POST /matching/like — replaces likeProfile Cloud Function
router.post('/like', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.body;
    if (!targetUid) { res.status(400).json({ code: 'MISSING_FIELD', error: 'targetUid required' }); return; }
    if (targetUid === req.uid) { res.status(400).json({ code: 'SELF_LIKE', error: 'Cannot like yourself' }); return; }

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
    let chat = null;
    if (mutual) {
      // Check no existing active match using `has` on both sides (PostgreSQL array containment)
      // hasEvery([A,B]) requires exact match; instead use AND has(A) + has(B)
      const existing = await prisma.match.findFirst({
        where: {
          AND: [
            { members: { has: req.uid } },
            { members: { has: targetUid } },
          ],
          status: 'active',
        },
      });

      if (!existing) {
        // Use transaction to prevent race condition on concurrent mutual likes
        const result = await prisma.$transaction(async (tx) => {
          // Double-check inside transaction
          const doubleCheck = await tx.match.findFirst({
            where: {
              AND: [
                { members: { has: req.uid } },
                { members: { has: targetUid } },
              ],
              status: 'active',
            },
          });
          if (doubleCheck) return { match: doubleCheck, chat: null, alreadyExisted: true };

          const newMatch = await tx.match.create({
            data: { members: [req.uid, targetUid] },
          });
          const newChat = await tx.chat.create({
            data: { members: [req.uid, targetUid], matchId: newMatch.id },
          });
          return { match: newMatch, chat: newChat, alreadyExisted: false };
        });

        match = result.match;
        chat = result.chat;

        if (!result.alreadyExisted) {
          // Fetch profiles for notifications
          const [myProfile, theirUser, theirProfile, myUser] = await Promise.all([
            prisma.profile.findUnique({ where: { userId: req.uid } }),
            prisma.user.findUnique({ where: { id: targetUid } }),
            prisma.profile.findUnique({ where: { userId: targetUid } }),
            prisma.user.findUnique({ where: { id: req.uid } }),
          ]);

          // Real-time Socket.IO emit to both users
          const matchPayload = {
            match,
            chat,
            otherProfile: null as any,
          };

          // Emit to the person who just got matched (targetUid) with sender's profile
          io.to(`user:${targetUid}`).emit('match:new', {
            ...matchPayload,
            otherProfile: myProfile,
          });

          // Emit to the sender with the target's profile
          io.to(`user:${req.uid}`).emit('match:new', {
            ...matchPayload,
            otherProfile: theirProfile,
          });

          // Push notification to the other user
          if (theirUser?.fcmToken && myProfile?.name) {
            await enqueuePush(
              theirUser.fcmToken,
              "It's a Match!",
              `You and ${myProfile.name} liked each other.`,
              { type: 'match', matchId: match.id, chatId: chat?.id ?? '' }
            );
          }

          // Push to self if on another device
          if (myUser?.fcmToken && theirProfile?.name) {
            await enqueuePush(
              myUser.fcmToken,
              "It's a Match!",
              `You and ${theirProfile.name} liked each other.`,
              { type: 'match', matchId: match.id, chatId: chat?.id ?? '' }
            );
          }
        }
      }
    }

    res.json({ liked: true, match, chat });
  } catch (err) {
    console.error('[matching/like]', err);
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to register like' });
  }
});

// POST /matching/skip — replaces skipProfile Cloud Function
router.post('/skip', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.body;
    if (!targetUid) { res.status(400).json({ code: 'MISSING_FIELD', error: 'targetUid required' }); return; }

    await prisma.skip.upsert({
      where: { senderUid_targetUid: { senderUid: req.uid, targetUid } },
      update: {},
      create: { senderUid: req.uid, targetUid },
    });

    res.json({ skipped: true });
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to register skip' });
  }
});

// GET /matching/matches — replaces getMatches Cloud Function
router.get('/matches', async (req: Request, res: Response) => {
  try {
    const matches = await prisma.match.findMany({
      where: { members: { has: req.uid }, status: 'active' },
      orderBy: { createdAt: 'desc' },
    });

    // Batch-fetch all other profiles (avoid N+1)
    const otherUids = matches.map((m) => m.members.find((id) => id !== req.uid)!).filter(Boolean);
    const profiles = await prisma.profile.findMany({ where: { userId: { in: otherUids } } });
    const profileByUid = Object.fromEntries(profiles.map((p) => [p.userId, p]));

    // Batch-fetch chats for these matches
    const matchIds = matches.map((m) => m.id);
    const chats = await prisma.chat.findMany({
      where: { matchId: { in: matchIds } },
      orderBy: { updatedAt: 'desc' },
    });
    const chatByMatchId = Object.fromEntries(chats.map((c) => [c.matchId!, c]));

    const enriched = matches.map((m) => {
      const otherUid = m.members.find((id) => id !== req.uid)!;
      return {
        ...m,
        otherProfile: profileByUid[otherUid] ?? null,
        chat: chatByMatchId[m.id] ?? null,
      };
    });

    res.json(enriched);
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch matches' });
  }
});

export default router;
