import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { enqueuePush } from '../jobs/queues';
import { scheduleMeltExpiry } from '../jobs/queues';

const router = Router();
router.use(requireAuth);

// POST /melt/invite — replaces sendMeltChatInvite Cloud Function
router.post('/invite', async (req: Request, res: Response) => {
  try {
    const { targetUid, slotLabel } = req.body;
    if (!targetUid) { res.status(400).json({ error: 'targetUid required' }); return; }

    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    const session = await prisma.meltSession.create({
      data: {
        hostUid: req.uid,
        targetUid,
        slotLabel,
        status: 'pending',
        expiresAt,
      },
    });

    // Schedule expiry job
    await scheduleMeltExpiry(session.id, expiresAt);

    // Push notification via queue (reliable delivery with retries)
    const [myProfile, theirUser] = await Promise.all([
      prisma.profile.findUnique({ where: { userId: req.uid } }),
      prisma.user.findUnique({ where: { id: targetUid } }),
    ]);

    if (theirUser?.fcmToken && myProfile?.name) {
      await enqueuePush(
        theirUser.fcmToken,
        'Melt Invite',
        `${myProfile.name} wants to connect with you.`,
        { type: 'melt_invite', sessionId: session.id }
      );
    }

    // Real-time: notify the target user of the new melt invite
    req.app.get('io').to(`user:${targetUid}`).emit('melt:invite', session);

    res.json(session);
  } catch (err) {
    console.error('[melt/invite]', err);
    res.status(500).json({ error: 'Failed to create Melt invite' });
  }
});

// PATCH /melt/invite/:id — accept or decline
router.patch('/invite/:id', async (req: Request, res: Response) => {
  try {
    const { status } = req.body; // 'accepted' | 'declined'
    if (!status) { res.status(400).json({ error: 'status required' }); return; }

    const session = await prisma.meltSession.findUnique({ where: { id: req.params.id } });
    if (!session || session.targetUid !== req.uid) {
      res.status(403).json({ error: 'Access denied' }); return;
    }
    if (session.expiresAt < new Date()) {
      res.status(410).json({ error: 'Session expired' }); return;
    }

    const updated = await prisma.meltSession.update({
      where: { id: req.params.id },
      data: { status },
    });

    // Real-time: notify both host and target of the status change
    const io = req.app.get('io');
    io.to(`user:${session.hostUid}`).emit('melt:status', updated);
    io.to(`user:${session.targetUid}`).emit('melt:status', updated);

    res.json(updated);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update Melt session' });
  }
});

// GET /melt/sessions — list active sessions for user
router.get('/sessions', async (req: Request, res: Response) => {
  try {
    const sessions = await prisma.meltSession.findMany({
      where: {
        OR: [{ hostUid: req.uid }, { targetUid: req.uid }],
        status: { in: ['pending', 'accepted'] },
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    res.json(sessions);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch Melt sessions' });
  }
});

export default router;
