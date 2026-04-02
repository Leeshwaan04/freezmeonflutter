import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';

const router = Router();
router.use(requireAuth);

// GET /chats — list user's chats
router.get('/', async (req: Request, res: Response) => {
  try {
    const chats = await prisma.chat.findMany({
      where: { members: { has: req.uid } },
      orderBy: { updatedAt: 'desc' },
      include: {
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });

    const enriched = await Promise.all(
      chats.map(async (chat) => {
        const otherUid = chat.members.find((id) => id !== req.uid)!;
        const profile = await prisma.profile.findUnique({ where: { userId: otherUid } });
        return { ...chat, otherProfile: profile };
      })
    );

    res.json(enriched);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch chats' });
  }
});

// GET /chats/:chatId/messages — paginated message history
router.get('/:chatId/messages', async (req: Request, res: Response) => {
  try {
    const { chatId } = req.params;
    const limit = Math.min(parseInt(req.query.limit as string ?? '50'), 100);
    const before = req.query.before as string | undefined;

    const chat = await prisma.chat.findUnique({ where: { id: chatId } });
    if (!chat || !chat.members.includes(req.uid)) {
      res.status(403).json({ error: 'Access denied' }); return;
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
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

export default router;
