import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';

const router = Router();
router.use(requireAuth);

// GET /chats — list user's chats (batch-fetch profiles, no N+1)
router.get('/', async (req: Request, res: Response) => {
  try {
    const chats = await prisma.chat.findMany({
      where: { members: { has: req.uid } },
      orderBy: { updatedAt: 'desc' },
      include: {
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });

    // Batch-fetch all other-user profiles in one query
    const otherUids = chats.map((c) => c.members.find((id) => id !== req.uid)!).filter(Boolean);
    const profiles = await prisma.profile.findMany({ where: { userId: { in: otherUids } } });
    const profileByUid = Object.fromEntries(profiles.map((p) => [p.userId, p]));

    const enriched = chats.map((chat) => {
      const otherUid = chat.members.find((id) => id !== req.uid)!;
      return { ...chat, otherProfile: profileByUid[otherUid] ?? null };
    });

    res.json(enriched);
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch chats' });
  }
});

// GET /chats/:chatId/messages — paginated message history
router.get('/:chatId/messages', async (req: Request, res: Response) => {
  try {
    const { chatId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string ?? '50'), 100);
    const before = req.query.before as string | undefined;

    const chat = await prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat) { res.status(404).json({ code: 'NOT_FOUND', error: 'Chat not found' }); return; }
    if (!chat.members.includes(req.uid)) {
      res.status(403).json({ code: 'FORBIDDEN', error: 'Access denied' }); return;
    }

    const messages = await prisma.message.findMany({
      where: {
        chatId,
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
    });

    res.json(messages.reverse());
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch messages' });
  }
});

// POST /chats/:chatId/read — mark all messages in chat as read
router.post('/:chatId/read', async (req: Request, res: Response) => {
  try {
    const { chatId } = req.params;
    const chat = await prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat || !chat.members.includes(req.uid)) {
      res.status(403).json({ code: 'FORBIDDEN', error: 'Access denied' }); return;
    }

    await prisma.message.updateMany({
      where: { chatId, senderUid: { not: req.uid }, status: { not: 'read' } },
      data: { status: 'read', readAt: new Date() },
    });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to mark chat as read' });
  }
});

export default router;
