import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { geohashForCoords, getGeohashRanges, kmBetween } from '../services/geo';
import { sendPushNotification } from '../services/fcm';

const router = Router();
router.use(requireAuth);

// POST /paths/presence — replaces upsertPathsPresence Cloud Function
router.post('/presence', async (req: Request, res: Response) => {
  try {
    const { lat, lng, intents, radiusKm, visibleForMinutes = 60 } = req.body;
    if (lat == null || lng == null) { res.status(400).json({ error: 'lat and lng required' }); return; }

    const geohash = geohashForCoords(lat, lng);
    const visibleUntil = new Date(Date.now() + visibleForMinutes * 60 * 1000);

    const presence = await prisma.pathsPresence.upsert({
      where: { uid: req.uid },
      update: { lat, lng, geohash, intents: intents ?? [], radiusKm: radiusKm ?? 5, visibleUntil },
      create: { uid: req.uid, lat, lng, geohash, intents: intents ?? [], radiusKm: radiusKm ?? 5, visibleUntil },
    });

    res.json(presence);
  } catch (err) {
    console.error('[paths/presence]', err);
    res.status(500).json({ error: 'Failed to update paths presence' });
  }
});

// DELETE /paths/presence — remove user's presence (go hidden)
router.delete('/presence', async (req: Request, res: Response) => {
  try {
    await prisma.pathsPresence.deleteMany({ where: { uid: req.uid } });
    res.json({ success: true });
  } catch (err) {
    console.error('[paths/presence DELETE]', err);
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

    // Batch-fetch all profiles in one query (avoids N+1)
    const uids = filtered.map((p) => p.uid);
    const profiles = await prisma.profile.findMany({ where: { userId: { in: uids } } });
    const profileByUid = Object.fromEntries(profiles.map((pr) => [pr.userId, pr]));

    const enriched = filtered.map((p) => ({ ...p, profile: profileByUid[p.uid] ?? null }));

    res.json(enriched);
  } catch (err) {
    console.error('[paths/nearby]', err);
    res.status(500).json({ error: 'Failed to fetch nearby paths' });
  }
});

// POST /paths/invite — replaces sendPathsInvite Cloud Function
router.post('/invite', async (req: Request, res: Response) => {
  try {
    const { receiverUid, intent } = req.body;
    if (!receiverUid || !intent) { res.status(400).json({ error: 'receiverUid and intent required' }); return; }

    const invite = await prisma.pathInvite.create({
      data: { senderUid: req.uid, receiverUid, intent },
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

    const invite = await prisma.pathInvite.findUnique({ where: { id: req.params.id } });
    if (!invite) { res.status(404).json({ error: 'Invite not found' }); return; }
    if (invite.receiverUid !== req.uid && invite.senderUid !== req.uid) {
      res.status(403).json({ error: 'Access denied' }); return;
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

// GET /paths/invites — list pending invites for user
router.get('/invites', async (req: Request, res: Response) => {
  try {
    const invites = await prisma.pathInvite.findMany({
      where: { receiverUid: req.uid, status: 'pending' },
      orderBy: { createdAt: 'desc' },
    });
    res.json(invites);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch path invites' });
  }
});

export default router;
