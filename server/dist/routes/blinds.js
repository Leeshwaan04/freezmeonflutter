"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const queues_1 = require("../jobs/queues");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
const BLIND_SESSION_MINUTES = 12;
// POST /blinds/enqueue — replaces enqueueBlind Cloud Function
router.post('/enqueue', async (req, res) => {
    try {
        const { intent, distanceBucket, interests } = req.body;
        if (!intent || !distanceBucket) {
            res.status(400).json({ error: 'intent and distanceBucket required' });
            return;
        }
        const availableUntil = new Date(Date.now() + 30 * 60 * 1000); // 30 min
        const entry = await client_1.prisma.blindsQueue.upsert({
            where: { uid: req.uid },
            update: { intent, distanceBucket, interests: interests ?? [], availableUntil },
            create: { uid: req.uid, intent, distanceBucket, interests: interests ?? [], availableUntil },
        });
        // Try to find a match immediately
        const match = await client_1.prisma.blindsQueue.findFirst({
            where: {
                uid: { not: req.uid },
                intent,
                distanceBucket,
                availableUntil: { gt: new Date() },
            },
        });
        if (match) {
            // Remove both from queue and create session
            await client_1.prisma.blindsQueue.deleteMany({ where: { uid: { in: [req.uid, match.uid] } } });
            const expiresAt = new Date(Date.now() + BLIND_SESSION_MINUTES * 60 * 1000);
            const session = await client_1.prisma.blindsSession.create({
                data: { userA: req.uid, userB: match.uid, expiresAt },
            });
            await (0, queues_1.scheduleBlindExpiry)(session.id, expiresAt);
            res.json({ queued: false, session });
        }
        else {
            res.json({ queued: true, entry });
        }
    }
    catch (err) {
        console.error('[blinds/enqueue]', err);
        res.status(500).json({ error: 'Failed to enqueue' });
    }
});
// DELETE /blinds/enqueue — replaces dequeueBlind Cloud Function
router.delete('/enqueue', async (req, res) => {
    try {
        await client_1.prisma.blindsQueue.deleteMany({ where: { uid: req.uid } });
        res.json({ dequeued: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to dequeue' });
    }
});
// GET /blinds/session — get active session for user
router.get('/session', async (req, res) => {
    try {
        const session = await client_1.prisma.blindsSession.findFirst({
            where: {
                OR: [{ userA: req.uid }, { userB: req.uid }],
                phase: { not: 'ended' },
                expiresAt: { gt: new Date() },
            },
            orderBy: { expiresAt: 'desc' },
        });
        res.json(session);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to fetch blind session' });
    }
});
// POST /blinds/session/:id/reveal — reveal identity
router.post('/session/:id/reveal', async (req, res) => {
    try {
        const session = await client_1.prisma.blindsSession.findUnique({ where: { id: req.params.id } });
        if (!session) {
            res.status(404).json({ error: 'Session not found' });
            return;
        }
        if (session.userA !== req.uid && session.userB !== req.uid) {
            res.status(403).json({ error: 'Access denied' });
            return;
        }
        const isUserA = session.userA === req.uid;
        const updated = await client_1.prisma.blindsSession.update({
            where: { id: req.params.id },
            data: isUserA ? { revealA: true } : { revealB: true },
        });
        res.json(updated);
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to reveal' });
    }
});
// POST /blinds/session/:id/report — replaces reportBlindSession Cloud Function
router.post('/session/:id/report', async (req, res) => {
    try {
        const { reason } = req.body;
        const session = await client_1.prisma.blindsSession.findUnique({ where: { id: req.params.id } });
        if (!session) {
            res.status(404).json({ error: 'Session not found' });
            return;
        }
        if (session.userA !== req.uid && session.userB !== req.uid) {
            res.status(403).json({ error: 'Access denied' });
            return;
        }
        await client_1.prisma.blindsSession.update({
            where: { id: req.params.id },
            data: { reported: true, reportReason: reason, phase: 'ended' },
        });
        res.json({ reported: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to report session' });
    }
});
exports.default = router;
//# sourceMappingURL=blinds.js.map