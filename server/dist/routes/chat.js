"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// GET /chats — list user's chats
router.get('/', async (req, res) => {
    try {
        const chats = await client_1.prisma.chat.findMany({
            where: { members: { has: req.uid } },
            orderBy: { updatedAt: 'desc' },
            include: {
                messages: { orderBy: { createdAt: 'desc' }, take: 1 },
            },
        });
        const enriched = await Promise.all(chats.map(async (chat) => {
            const otherUid = chat.members.find((id) => id !== req.uid);
            const profile = await client_1.prisma.profile.findUnique({ where: { userId: otherUid } });
            return { ...chat, otherProfile: profile };
        }));
        res.json(enriched);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch chats' });
    }
});
// GET /chats/:chatId/messages — paginated message history
router.get('/:chatId/messages', async (req, res) => {
    try {
        const { chatId } = req.params;
        const limit = Math.min(parseInt(req.query.limit ?? '50'), 100);
        const before = req.query.before;
        const chat = await client_1.prisma.chat.findUnique({ where: { id: chatId } });
        if (!chat || !chat.members.includes(req.uid)) {
            res.status(403).json({ error: 'Access denied' });
            return;
        }
        const messages = await client_1.prisma.message.findMany({
            where: {
                chatId,
                ...(before ? { createdAt: { lt: new Date(before) } } : {}),
            },
            orderBy: { createdAt: 'desc' },
            take: limit,
        });
        res.json(messages.reverse());
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch messages' });
    }
});
exports.default = router;
//# sourceMappingURL=chat.js.map