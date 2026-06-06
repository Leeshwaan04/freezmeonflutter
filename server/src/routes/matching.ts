import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const db = prisma as any;
import { io } from '../index';

const router = Router();
router.use(requireAuth);

// POST /matching/like — replaces likeProfile Cloud Function
router.post('/like', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.body;
    if (!targetUid) { res.status(400).json({ code: 'MISSING_FIELD', error: 'targetUid required' }); return; }
    if (targetUid === req.uid) { res.status(400).json({ code: 'SELF_LIKE', error: 'Cannot like yourself' }); return; }

    // Reject if either user has blocked the other
    const block = await db.block.findFirst({
      where: {
        OR: [
          { blockerUid: req.uid, blockedUid: targetUid },
          { blockerUid: targetUid, blockedUid: req.uid },
        ],
      },
    });
    if (block) { res.status(403).json({ code: 'BLOCKED', error: 'Action not allowed' }); return; }

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
        const activeMatchKey = [req.uid, targetUid].sort().join('_');
        try {
          const result = await prisma.$transaction(async (tx) => {
            // Double-check inside transaction
            const doubleCheck = await tx.match.findUnique({
              where: { activeMatchKey },
            });
            if (doubleCheck) return { match: doubleCheck, chat: null, alreadyExisted: true };

            const newMatch = await tx.match.create({
              data: { members: [req.uid, targetUid], activeMatchKey },
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
        } catch (e: any) {
          if (e.code === 'P2002') {
            // Concurrent match created
            match = await prisma.match.findUnique({ where: { activeMatchKey } });
            chat = await prisma.chat.findFirst({ where: { matchId: match?.id } });
          } else {
            throw e;
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

// GET /matching/likes — fetches profiles that have liked the current user (but not yet matched)
router.get('/likes', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(parseInt(req.query.limit as string ?? '50'), 50);

    // 1. Find who liked me
    const likes = await prisma.like.findMany({
      where: { targetUid: req.uid },
      orderBy: { likedAt: 'desc' },
      take: limit,
    });

    if (likes.length === 0) {
      res.json([]);
      return;
    }

    const senderUids = likes.map((l) => l.senderUid);

    // 2. Filter out anyone I've already liked (meaning we are matched) or skipped
    // Also filter out blocked users or users who blocked me.
    const [myLikesOrSkips, blocks, myMatches] = await Promise.all([
      prisma.like.findMany({ where: { senderUid: req.uid, targetUid: { in: senderUids } } }).then(l => l.map(x => x.targetUid))
        .then(async likesList => {
           const skips = await prisma.skip.findMany({ where: { senderUid: req.uid, targetUid: { in: senderUids } } });
           return [...likesList, ...skips.map(s => s.targetUid)];
        }),
      prisma.block.findMany({
        where: {
          OR: [
            { blockerUid: req.uid, blockedUid: { in: senderUids } },
            { blockerUid: { in: senderUids }, blockedUid: req.uid },
          ]
        }
      }),
      prisma.match.findMany({
        where: { members: { has: req.uid }, status: 'active' }
      })
    ]);

    const excludeUids = new Set([
      ...myLikesOrSkips,
      ...blocks.map((b) => b.blockerUid === req.uid ? b.blockedUid : b.blockerUid),
      ...myMatches.flatMap((m) => m.members)
    ]);

    const validSenderUids = senderUids.filter((uid) => !excludeUids.has(uid));

    if (validSenderUids.length === 0) {
      res.json([]);
      return;
    }

    // 3. Fetch their profiles
    const profiles = await prisma.profile.findMany({
      where: { userId: { in: validSenderUids } },
    });

    // Sort to match `likedAt` order
    const profileMap = new Map(profiles.map((p) => [p.userId, p]));
    const result = validSenderUids.map((uid) => profileMap.get(uid)).filter(Boolean);

    res.json(result);
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch likes' });
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

// POST /matching/unmatch — Unmatch a user
router.post('/unmatch', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.body;
    if (!targetUid) { res.status(400).json({ code: 'MISSING_FIELD', error: 'targetUid required' }); return; }

    const match = await prisma.match.findFirst({
      where: {
        AND: [
          { members: { has: req.uid } },
          { members: { has: targetUid } },
        ],
        status: 'active',
      },
    });

    if (!match) { res.status(404).json({ error: 'Match not found' }); return; }

    await prisma.$transaction(async (tx) => {
      // Mark match inactive
      await tx.match.update({ where: { id: match.id }, data: { status: 'unmatched', activeMatchKey: null } });
      
      // Delete the chat to remove it from both users' inboxes
      await tx.chat.deleteMany({ where: { matchId: match.id } });

      // Remove likes
      await tx.like.deleteMany({
        where: {
          OR: [
            { senderUid: req.uid, targetUid },
            { senderUid: targetUid, targetUid: req.uid },
          ]
        }
      });
      
      // Block the user to prevent rematching
      await tx.block.upsert({
        where: { blockerUid_blockedUid: { blockerUid: req.uid, blockedUid: targetUid } },
        update: {},
        create: { blockerUid: req.uid, blockedUid: targetUid },
      });
    });

    // Notify both users in real time so the match + chat disappear immediately
    // (the client listens for 'match:removed'). Previously never emitted, so an
    // unmatched/blocked match lingered until a manual refetch.
    io.to(`user:${req.uid}`).emit('match:removed', { matchId: match.id, otherUid: targetUid });
    io.to(`user:${targetUid}`).emit('match:removed', { matchId: match.id, otherUid: req.uid });

    res.json({ success: true });
  } catch (err) {
    console.error('[matching/unmatch]', err);
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to unmatch' });
  }
});

// GET /matching/liked-by — "Who Liked You". Returns the count always; returns
// the actual profiles only to premium users (free users see a blurred teaser
// driven by `count` + `isPremium:false` on the client).
router.get('/liked-by', async (req: Request, res: Response) => {
  try {
    // Incoming likes where I have NOT already liked them back and we're not blocked.
    const [incoming, myLikes, myMatches, blocks, membership] = await Promise.all([
      prisma.like.findMany({ where: { targetUid: req.uid }, orderBy: { likedAt: 'desc' } }),
      prisma.like.findMany({ where: { senderUid: req.uid }, select: { targetUid: true } }),
      prisma.match.findMany({ where: { members: { has: req.uid }, status: 'active' }, select: { members: true } }),
      prisma.block.findMany({ where: { OR: [{ blockerUid: req.uid }, { blockedUid: req.uid }] } }),
      prisma.membership.findUnique({ where: { userId: req.uid } }),
    ]);

    const likedBack = new Set(myLikes.map((l) => l.targetUid));
    const matchedUids = new Set(myMatches.flatMap((m) => m.members).filter((u) => u !== req.uid));
    const blockedUids = new Set(blocks.map((b) => (b.blockerUid === req.uid ? b.blockedUid : b.blockerUid)));

    const pendingAdmirers = incoming
      .map((l) => l.senderUid)
      .filter((uid) => !likedBack.has(uid) && !matchedUids.has(uid) && !blockedUids.has(uid));

    const isPremium = !!(membership?.active);
    const count = pendingAdmirers.length;

    if (!isPremium) {
      // Free tier: reveal the count, withhold identities (upsell).
      res.json({ count, isPremium: false, profiles: [] });
      return;
    }

    // Premium: return the actual profiles.
    const profiles = await prisma.profile.findMany({
      where: { userId: { in: pendingAdmirers } },
    });
    const byUid = Object.fromEntries(profiles.map((p) => [p.userId, p]));
    const ordered = pendingAdmirers
      .map((uid) => byUid[uid])
      .filter(Boolean)
      .map((p) => ({ ...p, uid: p.userId }));

    res.json({ count, isPremium: true, profiles: ordered });
  } catch (err) {
    console.error('[matching/liked-by]', err);
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch liked-by' });
  }
});

export default router;
