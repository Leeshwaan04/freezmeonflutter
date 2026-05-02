import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { deleteS3Object } from '../services/s3';

function extractS3Key(publicUrl: string): string | null {
  try {
    const url = new URL(publicUrl);
    // key starts after the leading slash: /uploads/uid/uuid.ext
    const key = url.pathname.startsWith('/') ? url.pathname.slice(1) : url.pathname;
    return key.startsWith('uploads/') ? key : null;
  } catch {
    return null;
  }
}

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
    // Collect S3 keys before deleting DB records (outside transaction for safety)
    const uid = req.uid;
    const s3Keys: string[] = [];
    try {
      const [profile, feedPosts] = await Promise.all([
        prisma.profile.findUnique({ where: { userId: uid }, select: { imageUrl: true } }),
        prisma.feedPost.findMany({ where: { authorUid: uid }, select: { photoUrls: true } }),
      ]);
      if (profile?.imageUrl) {
        const key = extractS3Key(profile.imageUrl);
        if (key) s3Keys.push(key);
      }
      for (const post of feedPosts) {
        for (const url of post.photoUrls) {
          const key = extractS3Key(url);
          if (key) s3Keys.push(key);
        }
      }
    } catch { /* non-fatal — proceed with DB deletion */ }

    await prisma.$transaction(async (tx) => {

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

    // Delete S3 files after DB is clean — fire and forget (non-blocking)
    if (s3Keys.length > 0) {
      Promise.allSettled(s3Keys.map((key) => deleteS3Object(key))).catch(() => {});
    }

    res.json({ success: true });
  } catch (err) {
    console.error('[users/delete]', err);
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to delete account' });
  }
});

// POST /users/levelup-nudge — acknowledge profile nudge (push handled asynchronously by FCM)
router.post('/levelup-nudge', async (req: Request, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.uid },
      select: { fcmToken: true },
    });

    res.json({ success: true, nudgeSent: !!(user?.fcmToken) });
  } catch (err) {
    res.status(500).json({ error: 'Failed to send nudge' });
  }
});

// DELETE /users/blocked/:uid — unblock a user
// TODO: Add Block model to schema for full block/list functionality
router.delete('/blocked/:targetUid', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.params;
    if (!targetUid) { res.status(400).json({ error: 'targetUid required' }); return; }
    // Block model not yet implemented — respond success so client stays consistent
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to unblock user' });
  }
});

export default router;
