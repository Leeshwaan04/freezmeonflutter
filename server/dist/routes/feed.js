"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// GET /feed
router.get('/', async (req, res) => {
    try {
        const limit = Math.min(parseInt(req.query.limit ?? '20'), 50);
        const before = req.query.before;
        const posts = await client_1.prisma.feedPost.findMany({
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
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch feed' });
    }
});
// POST /feed
router.post('/', async (req, res) => {
    try {
        const { content, photoUrls, visibility } = req.body;
        if (!content) {
            res.status(400).json({ error: 'content required' });
            return;
        }
        const post = await client_1.prisma.feedPost.create({
            data: {
                authorUid: req.uid,
                content,
                photoUrls: photoUrls ?? [],
                visibility: visibility ?? 'public',
            },
        });
        res.status(201).json(post);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to create post' });
    }
});
// POST /feed/:id/like
router.post('/:id/like', async (req, res) => {
    try {
        await client_1.prisma.postLike.upsert({
            where: { postId_uid: { postId: req.params.id, uid: req.uid } },
            update: {},
            create: { postId: req.params.id, uid: req.uid },
        });
        res.json({ liked: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to like post' });
    }
});
// DELETE /feed/:id/like
router.delete('/:id/like', async (req, res) => {
    try {
        await client_1.prisma.postLike.deleteMany({ where: { postId: req.params.id, uid: req.uid } });
        res.json({ liked: false });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to unlike post' });
    }
});
// GET /feed/:id/comments
router.get('/:id/comments', async (req, res) => {
    try {
        const comments = await client_1.prisma.postComment.findMany({
            where: { postId: req.params.id },
            orderBy: { createdAt: 'asc' },
        });
        res.json(comments);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch comments' });
    }
});
// POST /feed/:id/comments
router.post('/:id/comments', async (req, res) => {
    try {
        const { text } = req.body;
        if (!text) {
            res.status(400).json({ error: 'text required' });
            return;
        }
        const comment = await client_1.prisma.postComment.create({
            data: { postId: req.params.id, authorUid: req.uid, text },
        });
        res.status(201).json(comment);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to add comment' });
    }
});
exports.default = router;
//# sourceMappingURL=feed.js.map