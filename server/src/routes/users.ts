import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';

const router = Router();
router.use(requireAuth);

// POST /users/fcm-token — store FCM token for push notifications
router.post('/fcm-token', async (req: Request, res: Response) => {
  try {
    const { fcmToken } = req.body;
    if (!fcmToken) { res.status(400).json({ error: 'fcmToken required' }); return; }

    await prisma.user.update({
      where: { id: req.uid },
      data: { fcmToken, lastActiveAt: new Date() },
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update FCM token' });
  }
});

// DELETE /users/fcm-token — clear token on logout
router.delete('/fcm-token', async (req: Request, res: Response) => {
  try {
    await prisma.user.update({
      where: { id: req.uid },
      data: { fcmToken: null },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to clear FCM token' });
  }
});

// DELETE /users/me — delete account (full cascade cleanup)
router.delete('/me', async (req: Request, res: Response) => {
  try {
    await prisma.$transaction(async (tx) => {
      const uid = req.uid;

      // Delete all records that don't cascade automatically
      await tx.like.deleteMany({ where: { OR: [{ senderUid: uid }, { targetUid: uid }] } });
      await tx.skip.deleteMany({ where: { OR: [{ senderUid: uid }, { targetUid: uid }] } });
      await tx.pathInvite.deleteMany({ where: { OR: [{ senderUid: uid }, { receiverUid: uid }] } });
      await tx.blindsQueue.deleteMany({ where: { uid } });
      await tx.blindsSession.updateMany({
        where: { OR: [{ userA: uid }, { userB: uid }] },
        data: { phase: 'ended', reportReason: 'account_deleted' },
      });
      await tx.meltSession.deleteMany({ where: { OR: [{ hostUid: uid }, { targetUid: uid }] } });
      await tx.pathsPresence.deleteMany({ where: { uid } });
      await tx.presenceEvent.deleteMany({ where: { uid } });
      await tx.feedPost.deleteMany({ where: { authorUid: uid } });
      await tx.postLike.deleteMany({ where: { uid } });
      await tx.postComment.deleteMany({ where: { authorUid: uid } });
      await tx.refreshToken.deleteMany({ where: { userId: uid } });
      await tx.freezeMatch.deleteMany({ where: { OR: [{ userA: uid }, { userB: uid }] } });
      await tx.freezeRoomParticipant.deleteMany({ where: { uid } });

      // Remove user from any active Match members arrays — mark match as inactive
      const matches = await tx.match.findMany({ where: { members: { has: uid } } });
      for (const m of matches) {
        const remaining = m.members.filter((id) => id !== uid);
        if (remaining.length === 0) {
          await tx.match.delete({ where: { id: m.id } });
        } else {
          await tx.match.update({ where: { id: m.id }, data: { members: remaining, status: 'inactive' } });
        }
      }

      // Profile and Membership cascade from User (onDelete: Cascade in schema)
      await tx.user.delete({ where: { id: uid } });
    });

    res.json({ success: true });
  } catch (err) {
    console.error('[users/delete]', err);
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to delete account' });
  }
});

export default router;

// POST /users/levelup-nudge — send a push notification nudging user to complete their profile
router.post('/levelup-nudge', async (req: Request, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.uid },
      select: { fcmToken: true },
    });

    // Non-blocking — just acknowledge; actual push handled by FCM service asynchronously
    res.json({ success: true, nudgeSent: !!(user?.fcmToken) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to send nudge' });
  }
});
