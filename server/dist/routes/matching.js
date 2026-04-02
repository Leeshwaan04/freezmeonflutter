"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const queues_1 = require("../jobs/queues");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// POST /matching/like — replaces likeProfile Cloud Function
router.post('/like', async (req, res) => {
    try {
        const { targetUid } = req.body;
        if (!targetUid) {
            res.status(400).json({ error: 'targetUid required' });
            return;
        }
        if (targetUid === req.uid) {
            res.status(400).json({ error: 'Cannot like yourself' });
            return;
        }
        // Idempotent upsert
        await client_1.prisma.like.upsert({
            where: { senderUid_targetUid: { senderUid: req.uid, targetUid } },
            update: {},
            create: { senderUid: req.uid, targetUid },
        });
        // Check for mutual like → create match
        const mutual = await client_1.prisma.like.findUnique({
            where: { senderUid_targetUid: { senderUid: targetUid, targetUid: req.uid } },
        });
        let match = null;
        if (mutual) {
            // Check no existing active match
            const existing = await client_1.prisma.match.findFirst({
                where: { members: { hasEvery: [req.uid, targetUid] }, status: 'active' },
            });
            if (!existing) {
                match = await client_1.prisma.match.create({
                    data: { members: [req.uid, targetUid] },
                });
                // Create initial chat
                await client_1.prisma.chat.create({
                    data: { members: [req.uid, targetUid], matchId: match.id },
                });
                // Push notification to the other user
                const [myProfile, theirUser] = await Promise.all([
                    client_1.prisma.profile.findUnique({ where: { userId: req.uid } }),
                    client_1.prisma.user.findUnique({ where: { id: targetUid } }),
                ]);
                if (theirUser?.fcmToken && myProfile?.name) {
                    await (0, queues_1.enqueuePush)(theirUser.fcmToken, "It's a Match!", `You and ${myProfile.name} liked each other.`, { type: 'match', matchId: match.id });
                }
            }
        }
        res.json({ liked: true, match });
    }
    catch (err) {
        console.error('[matching/like]', err);
        res.status(500).json({ error: 'Failed to register like' });
    }
});
// POST /matching/skip — replaces skipProfile Cloud Function
router.post('/skip', async (req, res) => {
    try {
        const { targetUid } = req.body;
        if (!targetUid) {
            res.status(400).json({ error: 'targetUid required' });
            return;
        }
        await client_1.prisma.skip.upsert({
            where: { senderUid_targetUid: { senderUid: req.uid, targetUid } },
            update: {},
            create: { senderUid: req.uid, targetUid },
        });
        res.json({ skipped: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to register skip' });
    }
});
// GET /matching/matches — replaces getMatches Cloud Function
router.get('/matches', async (req, res) => {
    try {
        const matches = await client_1.prisma.match.findMany({
            where: { members: { has: req.uid }, status: 'active' },
            orderBy: { createdAt: 'desc' },
        });
        // Enrich with other user's profile
        const enriched = await Promise.all(matches.map(async (m) => {
            const otherUid = m.members.find((id) => id !== req.uid);
            const profile = await client_1.prisma.profile.findUnique({ where: { userId: otherUid } });
            return { ...m, otherProfile: profile };
        }));
        res.json(enriched);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch matches' });
    }
});
exports.default = router;
//# sourceMappingURL=matching.js.map