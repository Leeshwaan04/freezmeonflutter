import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';

const router = Router();
router.use(requireAuth);

// GET /feed
router.get('/', async (req: Request, res: Response) => {
  try {
    const limit = Math.min(parseInt(req.query.limit as string ?? '20'), 50);
    const before = req.query.before as string | undefined;

    const posts = await prisma.feedPost.findMany({
      where: {
        visibility: 'public',
        ...(before ? { createdAt: { lt: new Date(before) } } : {}),
      },
      orderBy: { createdAt: 'desc' },
      take: limit,
      include: {
        _count: { select: { likes: true, comments: true } },
      },
    });

    res.json(posts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch feed' });
  }
});

// POST /feed
router.post('/', async (req: Request, res: Response) => {
  try {
    const { content, photoUrls, visibility } = req.body;
    if (!content) { res.status(400).json({ error: 'content required' }); return; }

    const post = await prisma.feedPost.create({
      data: {
        authorUid: req.uid,
        content,
        photoUrls: photoUrls ?? [],
        visibility: visibility ?? 'public',
      },
    });

    res.status(201).json(post);
  } catch (err) {
    res.status(500).json({ error: 'Failed to create post' });
  }
});

// DELETE /feed/:id
router.delete('/:id', async (req: Request, res: Response) => {
  try {
    const post = await prisma.feedPost.findUnique({ where: { id: req.params.id } });
    if (!post) { res.status(404).json({ error: 'Post not found' }); return; }
    if (post.authorUid !== req.uid) { res.status(403).json({ error: 'Forbidden' }); return; }
    await prisma.feedPost.delete({ where: { id: req.params.id } });
    res.json({ deleted: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete post' });
  }
});

// POST /feed/:id/like
router.post('/:id/like', async (req: Request, res: Response) => {
  try {
    await prisma.postLike.upsert({
      where: { postId_uid: { postId: req.params.id, uid: req.uid } },
      update: {},
      create: { postId: req.params.id, uid: req.uid },
    });
    res.json({ liked: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to like post' });
  }
});

// DELETE /feed/:id/like
router.delete('/:id/like', async (req: Request, res: Response) => {
  try {
    await prisma.postLike.deleteMany({ where: { postId: req.params.id, uid: req.uid } });
    res.json({ liked: false });
  } catch (err) {
    res.status(500).json({ error: 'Failed to unlike post' });
  }
});

// GET /feed/:id/comments
router.get('/:id/comments', async (req: Request, res: Response) => {
  try {
    const comments = await prisma.postComment.findMany({
      where: { postId: req.params.id },
      orderBy: { createdAt: 'asc' },
    });
    res.json(comments);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch comments' });
  }
});

// POST /feed/:id/comments
router.post('/:id/comments', async (req: Request, res: Response) => {
  try {
    const { text } = req.body;
    if (!text) { res.status(400).json({ error: 'text required' }); return; }

    const comment = await prisma.postComment.create({
      data: { postId: req.params.id, authorUid: req.uid, text },
    });

    res.status(201).json(comment);
  } catch (err) {
    res.status(500).json({ error: 'Failed to add comment' });
  }
});

export default router;
