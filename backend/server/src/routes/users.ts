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

// DELETE /users/me — delete account
router.delete('/me', async (req: Request, res: Response) => {
  try {
    await prisma.user.delete({ where: { id: req.uid } });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

export default router;
