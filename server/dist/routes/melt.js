"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const queues_1 = require("../jobs/queues");
const queues_2 = require("../jobs/queues");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// POST /melt/invite — replaces sendMeltChatInvite Cloud Function
router.post('/invite', async (req, res) => {
    try {
        const { targetUid, slotLabel } = req.body;
        if (!targetUid) {
            res.status(400).json({ error: 'targetUid required' });
            return;
        }
        const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour
        const session = await client_1.prisma.meltSession.create({
            data: {
                hostUid: req.uid,
                targetUid,
                slotLabel,
                status: 'pending',
                expiresAt,
            },
        });
        // Schedule expiry job
        await (0, queues_2.scheduleMeltExpiry)(session.id, expiresAt);
        // Push notification via queue (reliable delivery with retries)
        const [myProfile, theirUser] = await Promise.all([
            client_1.prisma.profile.findUnique({ where: { userId: req.uid } }),
            client_1.prisma.user.findUnique({ where: { id: targetUid } }),
        ]);
        if (theirUser?.fcmToken && myProfile?.name) {
            await (0, queues_1.enqueuePush)(theirUser.fcmToken, 'Melt Invite', `${myProfile.name} wants to connect with you.`, { type: 'melt_invite', sessionId: session.id });
        }
        res.json(session);
    }
    catch (err) {
        console.error('[melt/invite]', err);
        res.status(500).json({ error: 'Failed to create Melt invite' });
    }
});
// PATCH /melt/invite/:id — accept or decline
router.patch('/invite/:id', async (req, res) => {
    try {
        const { status } = req.body; // 'accepted' | 'declined'
        if (!status) {
            res.status(400).json({ error: 'status required' });
            return;
        }
        const session = await client_1.prisma.meltSession.findUnique({ where: { id: req.params.id } });
        if (!session || session.targetUid !== req.uid) {
            res.status(403).json({ error: 'Access denied' });
            return;
        }
        if (session.expiresAt < new Date()) {
            res.status(410).json({ error: 'Session expired' });
            return;
        }
        const updated = await client_1.prisma.meltSession.update({
            where: { id: req.params.id },
            data: { status },
        });
        res.json(updated);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to update Melt session' });
    }
});
// GET /melt/sessions — list active sessions for user
router.get('/sessions', async (req, res) => {
    try {
        const sessions = await client_1.prisma.meltSession.findMany({
            where: {
                OR: [{ hostUid: req.uid }, { targetUid: req.uid }],
                status: { in: ['pending', 'accepted'] },
                expiresAt: { gt: new Date() },
            },
            orderBy: { createdAt: 'desc' },
        });
        res.json(sessions);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch Melt sessions' });
    }
});
exports.default = router;
//# sourceMappingURL=melt.js.map