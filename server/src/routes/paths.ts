import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { geohashForCoords, getGeohashRanges, kmBetween } from '../services/geo';
import { sendPushNotification } from '../services/fcm';
import { isValidLat, isValidLng } from '../utils/validate';
import { logger } from '../services/logger';
import { io } from '../index';

const router = Router();
router.use(requireAuth);

// POST /paths/presence — replaces upsertPathsPresence Cloud Function
router.post('/presence', async (req: Request, res: Response) => {
  try {
    const { lat, lng, intents, radiusKm, visibleForMinutes = 60 } = req.body;
    if (lat == null || lng == null) { res.status(400).json({ error: 'lat and lng required' }); return; }
    if (!isValidLat(lat) || !isValidLng(lng)) {
      res.status(400).json({ error: 'lat must be -90 to 90, lng must be -180 to 180' }); return;
    }
    if (visibleForMinutes < 1 || visibleForMinutes > 480) {
      res.status(400).json({ error: 'visibleForMinutes must be 1–480' }); return;
    }
    // Clamp discovery radius — prevents continent-wide stalking via radius=99999.
    const safeRadius = Math.min(Math.max(typeof radiusKm === 'number' ? radiusKm : 5, 0.1), 50);
    // Validate intents shape
    const safeIntents = Array.isArray(intents)
      ? intents.filter((s) => typeof s === 'string' && s.length <= 32).slice(0, 8)
      : [];

    const geohash = geohashForCoords(lat, lng);
    const visibleUntil = new Date(Date.now() + visibleForMinutes * 60 * 1000);

    const presence = await prisma.pathsPresence.upsert({
      where: { uid: req.uid },
      update: { lat, lng, geohash, intents: safeIntents, radiusKm: safeRadius, visibleUntil },
      create: { uid: req.uid, lat, lng, geohash, intents: safeIntents, radiusKm: safeRadius, visibleUntil },
    });

    res.json(presence);
  } catch (err) {
    logger.error({ msg: 'paths_presence_error', err });
    res.status(500).json({ error: 'Failed to update paths presence' });
  }
});

// DELETE /paths/presence — remove user's presence (go hidden)
router.delete('/presence', async (req: Request, res: Response) => {
  try {
    await prisma.pathsPresence.deleteMany({ where: { uid: req.uid } });
    res.json({ success: true });
  } catch (err) {
    logger.error({ msg: 'paths_presence_delete_error', err });
    res.status(500).json({ error: 'Failed to delete paths presence' });
  }
});

// GET /paths/nearby — replaces getNearbyPaths Cloud Function
router.get('/nearby', async (req: Request, res: Response) => {
  try {
    const lat = parseFloat(req.query.lat as string);
    const lng = parseFloat(req.query.lng as string);
    const radiusKm = parseFloat(req.query.radius as string ?? '5');

    if (isNaN(lat) || isNaN(lng)) { res.status(400).json({ error: 'lat and lng required' }); return; }
    if (!isValidLat(lat) || !isValidLng(lng)) {
      res.status(400).json({ error: 'lat must be -90 to 90, lng must be -180 to 180' }); return;
    }
    if (isNaN(radiusKm) || radiusKm < 0.1 || radiusKm > 100) {
      res.status(400).json({ error: 'radius must be 0.1–100 km' }); return;
    }

    const ranges = getGeohashRanges(lat, lng, radiusKm);
    const now = new Date();

    const nearby = await prisma.pathsPresence.findMany({
      where: {
        uid: { not: req.uid },
        visibleUntil: { gt: now },
        OR: ranges.map(([start, end]) => ({
          geohash: { gte: start, lte: end },
        })),
      },
    });

    // Filter by exact distance
    const filtered = nearby.filter((p) => kmBetween(lat, lng, p.lat, p.lng) <= radiusKm);

    // Exclude blocked users
    const candidateUids = filtered.map((p) => p.uid);
    const blocks = await prisma.block.findMany({
      where: { OR: [
        { blockerUid: req.uid, blockedUid: { in: candidateUids } },
        { blockedUid: req.uid, blockerUid: { in: candidateUids } },
      ] },
    });
    const blockedSet = new Set(blocks.map((b) => b.blockerUid === req.uid ? b.blockedUid : b.blockerUid));
    const unblocked = filtered.filter((p) => !blockedSet.has(p.uid));

    // Batch-fetch all profiles in one query (avoids N+1).
    // PRIVACY: select ONLY display-safe fields. We must never load (let alone
    // return) another nearby user's home lat/lng/geohash — proximity is conveyed
    // solely via the rounded `distanceKm` computed below. Returning raw coords
    // here would let a client triangulate someone's exact home/whereabouts.
    const uids = unblocked.map((p) => p.uid);
    const profiles = await prisma.profile.findMany({
      where: { userId: { in: uids } },
      select: {
        userId: true,
        name: true,
        age: true,
        gender: true,
        imageUrl: true,
        isVerified: true,
        intent: true,
      },
    });
    const profileByUid = Object.fromEntries(profiles.map((pr) => [pr.userId, pr]));

    // PRIVACY: never expose raw lat/lng/geohash of other users. Return only the
    // distance from the requester (snapped to ~100m) so the client can render a
    // proximity indicator without enabling stalking.
    const page = parseInt(req.query.page as string ?? '1', 10);
    const limit = parseInt(req.query.limit as string ?? '50', 10);
    const safePage = Math.max(page, 1);
    const safeLimit = Math.min(Math.max(limit, 1), 100);

    const enriched = unblocked.map((p) => {
      const distanceKm = kmBetween(lat, lng, p.lat, p.lng);
      const distanceRoundedKm = Math.round(distanceKm * 10) / 10; // 100m granularity
      const { lat: _lat, lng: _lng, geohash: _geo, ...safe } = p as any;
      return { ...safe, distanceKm: distanceRoundedKm, profile: profileByUid[p.uid] ?? null };
    });

    // Sort by distance and paginate
    enriched.sort((a, b) => a.distanceKm - b.distanceKm);
    const paginated = enriched.slice((safePage - 1) * safeLimit, safePage * safeLimit);

    res.json(paginated);
  } catch (err) {
    logger.error({ msg: 'paths_nearby_error', err });
    res.status(500).json({ error: 'Failed to fetch nearby paths' });
  }
});

// POST /paths/invite — replaces sendPathsInvite Cloud Function
router.post('/invite', async (req: Request, res: Response) => {
  try {
    const { receiverUid, intent } = req.body;
    if (!receiverUid || !intent) { res.status(400).json({ code: 'MISSING_FIELD', error: 'receiverUid and intent required' }); return; }
    if (receiverUid === req.uid) { res.status(400).json({ code: 'INVALID_RECEIVER', error: 'Cannot invite yourself' }); return; }

    // Verify receiver exists to avoid orphaned invites
    const receiverExists = await prisma.user.findUnique({ where: { id: receiverUid }, select: { id: true } });
    if (!receiverExists) { res.status(404).json({ code: 'USER_NOT_FOUND', error: 'Receiver not found' }); return; }

    // Prevent duplicate pending invites between same pair
    const duplicateInvite = await prisma.pathInvite.findFirst({
      where: { senderUid: req.uid, receiverUid, status: 'pending', expiresAt: { gt: new Date() } },
    });
    if (duplicateInvite) { res.status(409).json({ code: 'ALREADY_INVITED', error: 'You already have a pending invite to this user' }); return; }

    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24h expiry
    const invite = await prisma.pathInvite.create({
      data: { senderUid: req.uid, receiverUid, intent, expiresAt },
    });

    // Push to receiver
    const [receiverUser, senderProfile] = await Promise.all([
      prisma.user.findUnique({ where: { id: receiverUid } }),
      prisma.profile.findUnique({ where: { userId: req.uid } }),
    ]);
    if (receiverUser?.fcmToken && senderProfile?.name) {
      sendPushNotification(
        receiverUser.fcmToken,
        'Someone crossed your path',
        `${senderProfile.name} wants to connect — ${intent}`,
        { type: 'paths_invite', inviteId: invite.id }
      ).catch(() => {});
    }

    // Real-time: notify the receiver immediately so a wave appears live (the
    // client listens for 'paths:invite'). Previously never emitted — waves only
    // arrived via polling GET /paths/invites.
    io.to(`user:${receiverUid}`).emit('paths:invite', {
      invite,
      senderName: senderProfile?.name ?? null,
    });

    res.json(invite);
  } catch (err) {
    res.status(500).json({ error: 'Failed to send paths invite' });
  }
});

// POST /paths/invite/:id/respond — replaces respondPathsInvite Cloud Function
router.post('/invite/:id/respond', async (req: Request, res: Response) => {
  try {
    const { status } = req.body; // 'accepted' | 'declined' | 'cancelled'
    if (!status) { res.status(400).json({ error: 'status required' }); return; }
    if (!['accepted', 'declined', 'cancelled'].includes(status)) {
      res.status(400).json({ error: 'status must be accepted, declined, or cancelled' }); return;
    }

    const invite = await prisma.pathInvite.findUnique({ where: { id: req.params.id } });
    if (!invite) { res.status(404).json({ error: 'Invite not found' }); return; }
    if (invite.status !== 'pending') { res.status(409).json({ error: 'Invite already responded to' }); return; }
    if (invite.expiresAt < new Date()) { res.status(410).json({ error: 'Invite has expired' }); return; }

    // Only receiver can accept/decline; only sender can cancel
    if (status === 'cancelled' && invite.senderUid !== req.uid) {
      res.status(403).json({ error: 'Only the sender can cancel an invite' }); return;
    }
    if ((status === 'accepted' || status === 'declined') && invite.receiverUid !== req.uid) {
      res.status(403).json({ error: 'Only the receiver can accept or decline' }); return;
    }

    const updated = await prisma.pathInvite.update({
      where: { id: req.params.id },
      data: { status, respondedAt: new Date() },
    });

    // On accept, create a chat and notify the original sender
    let chat = null;
    if (status === 'accepted') {
      chat = await prisma.chat.create({
        data: { members: [invite.senderUid, invite.receiverUid] },
      });

      const [senderUser, accepterProfile] = await Promise.all([
        prisma.user.findUnique({ where: { id: invite.senderUid } }),
        prisma.profile.findUnique({ where: { userId: req.uid } }),
      ]);
      if (senderUser?.fcmToken && accepterProfile?.name) {
        sendPushNotification(
          senderUser.fcmToken,
          'Path invite accepted!',
          `${accepterProfile.name} accepted your invite. Say hello!`,
          { type: 'paths_accepted', chatId: chat.id }
        ).catch(() => {});
      }
    }

    res.json({ invite: updated, chat });
  } catch (err) {
    res.status(500).json({ error: 'Failed to respond to paths invite' });
  }
});

// GET /paths/invites — list pending invites for user (exclude expired)
router.get('/invites', async (req: Request, res: Response) => {
  try {
    const invites = await prisma.pathInvite.findMany({
      where: {
        receiverUid: req.uid,
        status: 'pending',
        expiresAt: { gt: new Date() }, // exclude expired
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json(invites);
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch path invites' });
  }
});

export default router;
