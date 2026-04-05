import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { geohashForCoords } from '../services/geo';

const router = Router();
router.use(requireAuth);

// ── Compatibility matrix for personality trait pairs ────────────────────────
// Complementary pairings score higher than identical ones where research supports it
const TRAIT_COMPAT: Record<string, Record<string, number>> = {
  introvert:   { introvert: 0.6, extrovert: 1.0, adventurous: 0.7, cautious: 0.8, logical: 0.7, emotional: 0.8, spontaneous: 0.6, planner: 0.9 },
  extrovert:   { introvert: 1.0, extrovert: 0.7, adventurous: 0.9, cautious: 0.6, logical: 0.6, emotional: 0.8, spontaneous: 0.9, planner: 0.6 },
  adventurous: { introvert: 0.7, extrovert: 0.9, adventurous: 1.0, cautious: 0.8, logical: 0.6, emotional: 0.7, spontaneous: 1.0, planner: 0.6 },
  cautious:    { introvert: 0.8, extrovert: 0.6, adventurous: 0.8, cautious: 0.6, logical: 0.9, emotional: 0.7, spontaneous: 0.6, planner: 1.0 },
  logical:     { introvert: 0.7, extrovert: 0.6, adventurous: 0.6, cautious: 0.9, logical: 0.7, emotional: 1.0, spontaneous: 0.6, planner: 0.8 },
  emotional:   { introvert: 0.8, extrovert: 0.8, adventurous: 0.7, cautious: 0.7, logical: 1.0, emotional: 0.7, spontaneous: 0.8, planner: 0.7 },
  spontaneous: { introvert: 0.6, extrovert: 0.9, adventurous: 1.0, cautious: 0.6, logical: 0.6, emotional: 0.8, spontaneous: 0.7, planner: 0.9 },
  planner:     { introvert: 0.9, extrovert: 0.6, adventurous: 0.6, cautious: 1.0, logical: 0.8, emotional: 0.7, spontaneous: 0.9, planner: 0.6 },
};

function traitCompatScore(myTraits: string[], theirTraits: string[]): number {
  if (!myTraits.length || !theirTraits.length) return 0.5;
  let total = 0, count = 0;
  for (const mine of myTraits) {
    for (const theirs of theirTraits) {
      total += TRAIT_COMPAT[mine]?.[theirs] ?? 0.5;
      count++;
    }
  }
  return count > 0 ? total / count : 0.5;
}

function interestOverlap(a: string[], b: string[]): number {
  if (!a.length || !b.length) return 0;
  const setA = new Set(a.map(s => s.toLowerCase()));
  const overlap = b.filter(s => setA.has(s.toLowerCase())).length;
  return overlap / Math.min(a.length, b.length);
}

function intentScore(mine: string | null, theirs: string | null): number {
  if (!mine || !theirs) return 0.5;
  if (mine === theirs) return 1.0;
  // exploring + meaningful is ok, friendship alone is its own thing
  if ((mine === 'exploring' && theirs === 'meaningful') ||
      (mine === 'meaningful' && theirs === 'exploring')) return 0.7;
  return 0.2;
}

function recencyScore(updatedAt: Date): number {
  const hoursAgo = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60);
  if (hoursAgo < 24)  return 1.0;
  if (hoursAgo < 48)  return 0.8;
  if (hoursAgo < 168) return 0.5; // 1 week
  return 0.1;
}

function lifestyleOverlap(a: string[], b: string[]): number {
  if (!a.length || !b.length) return 0;
  const setA = new Set(a);
  const overlap = b.filter(s => setA.has(s)).length;
  return overlap / Math.min(a.length, b.length);
}

// POST /profiles — create or update profile
router.post('/', async (req: Request, res: Response) => {
  try {
    const {
      name, age, bio, imageUrl, interests,
      intent, personalityTraits, lifestyleFactors, archetype, promptAnswer,
      energyType, paceSignal, presenceWindows,
    } = req.body;

    if (!name || !age) { res.status(400).json({ error: 'name and age required' }); return; }

    const profile = await prisma.profile.upsert({
      where: { userId: req.uid },
      update: {
        name, age, bio, imageUrl,
        interests: interests ?? [],
        ...(intent !== undefined && { intent }),
        ...(personalityTraits !== undefined && { personalityTraits }),
        ...(lifestyleFactors !== undefined && { lifestyleFactors }),
        ...(archetype !== undefined && { archetype }),
        ...(promptAnswer !== undefined && { promptAnswer }),
        ...(energyType !== undefined && { energyType }),
        ...(paceSignal !== undefined && { paceSignal }),
        ...(presenceWindows !== undefined && { presenceWindows }),
      },
      create: {
        userId: req.uid,
        name, age, bio, imageUrl,
        interests: interests ?? [],
        intent: intent ?? null,
        personalityTraits: personalityTraits ?? [],
        lifestyleFactors: lifestyleFactors ?? [],
        archetype: archetype ?? null,
        promptAnswer: promptAnswer ?? null,
        energyType: energyType ?? null,
        paceSignal: paceSignal ?? null,
        presenceWindows: presenceWindows ?? null,
      },
    });

    res.json({ ...profile, uid: profile.userId });
  } catch (err) {
    console.error('[profiles POST]', err);
    res.status(500).json({ error: 'Failed to save profile' });
  }
});

// GET /profiles/me
router.get('/me', async (req: Request, res: Response) => {
  try {
    const profile = await prisma.profile.findUnique({ where: { userId: req.uid } });
    if (!profile) { res.status(404).json({ error: 'Profile not found' }); return; }
    res.json({ ...profile, uid: profile.userId });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// GET /profiles/daily-pool — scored discovery algorithm
router.get('/daily-pool', async (req: Request, res: Response) => {
  try {
    const uid = req.uid;

    const [likes, skips, myProfile] = await Promise.all([
      prisma.like.findMany({ where: { senderUid: uid }, select: { targetUid: true } }),
      prisma.skip.findMany({ where: { senderUid: uid }, select: { targetUid: true } }),
      prisma.profile.findUnique({ where: { userId: uid } }),
    ]);

    const excluded = new Set([uid, ...likes.map(l => l.targetUid), ...skips.map(s => s.targetUid)]);

    // Who already liked me — these get a huge boost
    const pendingLikesForMe = await prisma.like.findMany({
      where: { targetUid: uid, senderUid: { notIn: Array.from(excluded) } },
      select: { senderUid: true },
    });
    const pendingLikerUids = new Set(pendingLikesForMe.map(l => l.senderUid));

    // Fetch candidate pool — 60 candidates to score down to 20
    const candidates = await prisma.profile.findMany({
      where: {
        userId: { notIn: Array.from(excluded) },
        frozen: false,
      },
      take: 60,
      orderBy: { presenceScore: 'desc' },
    });

    // Score each candidate
    const scored = candidates.map(c => {
      const mutualPending  = pendingLikerUids.has(c.userId) ? 50 : 0;
      const intent         = intentScore(myProfile?.intent ?? null, c.intent ?? null) * 25;
      const interests      = interestOverlap(myProfile?.interests ?? [], c.interests) * 25;
      const traits         = traitCompatScore(myProfile?.personalityTraits ?? [], c.personalityTraits) * 20;
      const lifestyle      = lifestyleOverlap(myProfile?.lifestyleFactors ?? [], c.lifestyleFactors) * 15;
      const recency        = recencyScore(c.updatedAt) * 10;
      const presence       = (c.presenceScore / 100) * 5;

      const total = mutualPending + intent + interests + traits + lifestyle + recency + presence;

      // Shared interests for display
      const myInterestSet = new Set((myProfile?.interests ?? []).map(s => s.toLowerCase()));
      const sharedInterests = c.interests.filter(i => myInterestSet.has(i.toLowerCase()));

      return {
        ...c,
        uid: c.userId,
        _score: total,
        sharedInterests,
        compatibilityScore: Math.round(
          (intent / 25 + interests / 25 + traits / 20 + lifestyle / 15) / 4 * 100
        ),
      };
    });

    // Sort by score, take top 20
    scored.sort((a, b) => b._score - a._score);
    const pool = scored.slice(0, 20).map(({ _score, ...p }) => p);

    res.json(pool);
  } catch (err) {
    console.error('[profiles/daily-pool]', err);
    res.status(500).json({ error: 'Failed to fetch daily pool' });
  }
});

// GET /profiles/:uid — view another user's profile
router.get('/:uid', async (req: Request, res: Response) => {
  try {
    const profile = await prisma.profile.findUnique({ where: { userId: req.params.uid } });
    if (!profile) { res.status(404).json({ error: 'Profile not found' }); return; }
    res.json({ ...profile, uid: profile.userId });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PATCH /profiles/location
router.patch('/location', async (req: Request, res: Response) => {
  try {
    const { lat, lng } = req.body;
    if (lat == null || lng == null) { res.status(400).json({ error: 'lat and lng required' }); return; }
    const geohash = geohashForCoords(lat, lng);
    await prisma.profile.update({
      where: { userId: req.uid },
      data: { lat, lng, geohash },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update location' });
  }
});

// PATCH /profiles/freeze
router.patch('/freeze', async (req: Request, res: Response) => {
  try {
    const { frozen, freezeUntil } = req.body;
    await prisma.profile.update({
      where: { userId: req.uid },
      data: {
        frozen: frozen ?? false,
        freezeUntil: freezeUntil ? new Date(freezeUntil) : null,
        presenceLabel: frozen ? 'frozen' : 'in_the_flow',
      },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update freeze status' });
  }
});

// PATCH /profiles/presence-window — set weekly availability windows
router.patch('/presence-window', async (req: Request, res: Response) => {
  try {
    const { presenceWindows } = req.body;
    if (!Array.isArray(presenceWindows)) {
      res.status(400).json({ error: 'presenceWindows must be an array' }); return;
    }
    await prisma.profile.update({
      where: { userId: req.uid },
      data: { presenceWindows },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update presence window' });
  }
});

export default router;
