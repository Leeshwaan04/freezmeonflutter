import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { deleteS3Object } from '../services/s3';
// eslint-disable-next-line @typescript-eslint/no-explicit-any
const db = prisma as any;

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

// DELETE /users/me — delete account (hard delete)
router.delete('/me', async (req: Request, res: Response) => {
  try {
    const uid = req.uid;

    await prisma.$transaction(async (tx) => {
      // 1. Clear all refresh tokens so they are logged out
      await tx.refreshToken.deleteMany({ where: { userId: uid } });

      // 2. Mark matches as inactive so they disappear from other users' inboxes immediately
      const matches = await tx.match.findMany({ where: { members: { has: uid } } });
      for (const m of matches) {
        await tx.match.update({ where: { id: m.id }, data: { status: 'inactive' } });
      }

      // 3. Remove them from active pools, presences, or queues to hide their profile
      await tx.blindsQueue.deleteMany({ where: { uid } });
      await tx.pathsPresence.deleteMany({ where: { uid } });

      // 4. Delete their feed posts, likes, and reports
      await tx.feedPost.deleteMany({ where: { authorUid: uid } });
      await tx.like.deleteMany({ where: { senderUid: uid } });
      await tx.report.deleteMany({ where: { reporterUid: uid } });

      // 5. Delete all chats and messages for this user
      const userChats = await tx.chat.findMany({ where: { members: { has: uid } } });
      for (const chat of userChats) {
        await tx.chatMessage.deleteMany({ where: { chatId: chat.id } });
        await tx.chat.delete({ where: { id: chat.id } });
      }

      // 6. Delete blocks and melt invites
      await tx.block.deleteMany({ where: { OR: [{ blockerUid: uid }, { blockedUid: uid }] } });
      await tx.meltInvite.deleteMany({ where: { OR: [{ senderUid: uid }, { receiverUid: uid }] } });

      // 7. Delete profile
      await tx.profile.deleteMany({ where: { userId: uid } });

      // 8. Delete membership
      await tx.membership.deleteMany({ where: { userId: uid } });

      // 9. Delete the user completely
      await tx.user.delete({ where: { id: uid } });
    });

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

// POST /users/blocked/:targetUid — block a user
router.post('/blocked/:targetUid', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.params;
    if (targetUid === req.uid) { res.status(400).json({ error: 'Cannot block yourself' }); return; }
    await db.block.upsert({
      where: { blockerUid_blockedUid: { blockerUid: req.uid, blockedUid: targetUid } },
      update: {},
      create: { blockerUid: req.uid, blockedUid: targetUid },
    });
    res.json({ blocked: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to block user' });
  }
});

// DELETE /users/blocked/:targetUid — unblock a user
router.delete('/blocked/:targetUid', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.params;
    await db.block.deleteMany({
      where: { blockerUid: req.uid, blockedUid: targetUid },
    });
    res.json({ blocked: false });
  } catch (err) {
    res.status(500).json({ error: 'Failed to unblock user' });
  }
});

// POST /users/:targetUid/report — file a report and auto-block
router.post('/:targetUid/report', async (req: Request, res: Response) => {
  try {
    const { targetUid } = req.params;
    if (targetUid === req.uid) { res.status(400).json({ error: 'Cannot report yourself' }); return; }

    const { reason, details, context, contextId } = req.body ?? {};
    const validReasons = ['inappropriate', 'harassment', 'spam', 'fake', 'underage', 'other'];
    const safeReason = typeof reason === 'string' && validReasons.includes(reason) ? reason : 'other';
    const safeDetails = typeof details === 'string' ? details.slice(0, 1000) : null;
    const safeContext = typeof context === 'string' && ['chat', 'profile', 'feed', 'melt', 'blinds', 'freeze_room'].includes(context) ? context : null;
    const safeContextId = typeof contextId === 'string' ? contextId.slice(0, 64) : null;

    await db.report.create({
      data: {
        reporterUid: req.uid,
        reportedUid: targetUid,
        reason: safeReason,
        details: safeDetails,
        context: safeContext,
        contextId: safeContextId,
      },
    });

    // Auto-block on report (Apple Trust & Safety expectation)
    await db.block.upsert({
      where: { blockerUid_blockedUid: { blockerUid: req.uid, blockedUid: targetUid } },
      update: {},
      create: { blockerUid: req.uid, blockedUid: targetUid },
    });

    res.json({ reported: true, blocked: true });
  } catch (err) {
    console.error('[users/report]', err);
    res.status(500).json({ error: 'Failed to file report' });
  }
});

// GET /users/blocked — list blocked users
router.get('/blocked', async (req: Request, res: Response) => {
  try {
    const blocks = await db.block.findMany({
      where: { blockerUid: req.uid },
      select: { blockedUid: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
    res.json(blocks);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch block list' });
  }
});

// GET /users/me/export — GDPR data export
router.get('/me/export', async (req: Request, res: Response) => {
  try {
    const uid = req.uid;
    const user = await prisma.user.findUnique({ where: { id: uid } });
    const profile = await prisma.profile.findUnique({ where: { userId: uid } });
    const posts = await prisma.feedPost.findMany({ where: { authorUid: uid } });
    const matches = await prisma.match.findMany({ where: { members: { has: uid } } });
    // Strip sensitive fields
    const safeUser = user ? { ...user, passwordHash: undefined } : null;
    
    res.json({
      user: safeUser,
      profile,
      posts,
      matches,
      exportedAt: new Date().toISOString(),
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to export data' });
  }
});

// POST /users/feedback — submit feedback / contact support
router.post('/feedback', async (req: Request, res: Response) => {
  try {
    const { category, message, email, platform } = req.body;
    if (!message) { res.status(400).json({ error: 'Message required' }); return; }

    await db.feedback.create({
      data: {
        uid: req.uid,
        email,
        category: category ?? 'general',
        message: String(message).slice(0, 4000),
        platform,
      },
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to submit feedback' });
  }
});

// GET /users/notification-prefs — per-type push preferences (with defaults)
router.get('/notification-prefs', async (req: Request, res: Response) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.uid },
      select: { notificationPrefs: true },
    });
    const defaults = { matches: true, messages: true, likes: true, marketing: false };
    const stored = (user?.notificationPrefs as Record<string, boolean> | null) ?? {};
    res.json({ ...defaults, ...stored });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch notification preferences' });
  }
});

// PATCH /users/notification-prefs — update preferences (whitelisted keys only)
router.patch('/notification-prefs', async (req: Request, res: Response) => {
  try {
    const allowed = ['matches', 'messages', 'likes', 'marketing'];
    const incoming = req.body ?? {};
    const existing = await prisma.user.findUnique({
      where: { id: req.uid },
      select: { notificationPrefs: true },
    });
    const merged: Record<string, boolean> = {
      ...((existing?.notificationPrefs as Record<string, boolean> | null) ?? {}),
    };
    for (const key of allowed) {
      if (typeof incoming[key] === 'boolean') merged[key] = incoming[key];
    }
    await prisma.user.update({
      where: { id: req.uid },
      data: { notificationPrefs: merged },
    });
    res.json(merged);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update notification preferences' });
  }
});

// POST /users/me/schedule-deletion — soft-delete (30-day recoverable window).
// The purge_deleted_accounts cron permanently removes the account after 30 days
// of inactivity; logging back in before then reactivates it.
router.post('/me/schedule-deletion', async (req: Request, res: Response) => {
  try {
    await prisma.$transaction([
      prisma.user.update({
        where: { id: req.uid },
        data: { status: 'deleted', fcmToken: null, lastActiveAt: new Date() },
      }),
      // Log them out everywhere and pull them from discovery immediately.
      prisma.refreshToken.deleteMany({ where: { userId: req.uid } }),
      prisma.pathsPresence.deleteMany({ where: { uid: req.uid } }),
      prisma.blindsQueue.deleteMany({ where: { uid: req.uid } }),
    ]);
    res.json({ success: true, status: 'scheduled', recoverableUntilDays: 30 });
  } catch (err) {
    console.error('[users/schedule-deletion]', err);
    res.status(500).json({ error: 'Failed to schedule deletion' });
  }
});

export default router;
