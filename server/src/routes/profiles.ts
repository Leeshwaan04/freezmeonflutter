import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { geohashForCoords } from '../services/geo';

const router = Router();
router.use(requireAuth);

// POST /profiles — create or update profile (replaces createProfile Cloud Function)
router.post('/', async (req: Request, res: Response) => {
  try {
    const { name, age, bio, imageUrl, interests } = req.body;
    if (!name || !age) { res.status(400).json({ error: 'name and age required' }); return; }

    const profile = await prisma.profile.upsert({
      where: { userId: req.uid },
      update: { name, age, bio, imageUrl, interests: interests ?? [] },
      create: {
        userId: req.uid,
        name,
        age,
        bio,
        imageUrl,
        interests: interests ?? [],
      },
    });

    res.json(profile);
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
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// GET /profiles/daily-pool — replaces getDailyPool Cloud Function
router.get('/daily-pool', async (req: Request, res: Response) => {
  try {
    const uid = req.uid;

    // Get UIDs already liked or skipped
    const [likes, skips] = await Promise.all([
      prisma.like.findMany({ where: { senderUid: uid }, select: { targetUid: true } }),
      prisma.skip.findMany({ where: { senderUid: uid }, select: { targetUid: true } }),
    ]);

    const excluded = new Set([uid, ...likes.map((l) => l.targetUid), ...skips.map((s) => s.targetUid)]);

    const myProfile = await prisma.profile.findUnique({ where: { userId: uid } });

    const candidates = await prisma.profile.findMany({
      where: {
        userId: { notIn: Array.from(excluded) },
      },
      take: 20,
      orderBy: { updatedAt: 'desc' },
    });

    res.json(candidates);
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
    res.json(profile);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PATCH /profiles/location — update geolocation
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


// PATCH /profiles/freeze — toggle freeze mode
router.patch('/freeze', async (req: Request, res: Response) => {
  try {
    const { frozen, freezeUntil } = req.body;
    await prisma.profile.update({
      where: { userId: req.uid },
      data: { frozen: frozen ?? false, freezeUntil: freezeUntil ? new Date(freezeUntil) : null },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update freeze status' });
  }
});

export default router;
