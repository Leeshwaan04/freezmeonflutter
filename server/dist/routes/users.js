"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// POST /users/fcm-token — store FCM token for push notifications
router.post('/fcm-token', async (req, res) => {
    try {
        const { fcmToken } = req.body;
        if (!fcmToken) {
            res.status(400).json({ error: 'fcmToken required' });
            return;
        }
        await client_1.prisma.user.update({
            where: { id: req.uid },
            data: { fcmToken, lastActiveAt: new Date() },
        });
        res.json({ success: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to update FCM token' });
    }
});
// DELETE /users/fcm-token — clear token on logout
router.delete('/fcm-token', async (req, res) => {
    try {
        await client_1.prisma.user.update({
            where: { id: req.uid },
            data: { fcmToken: null },
        });
        res.json({ success: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to clear FCM token' });
    }
});
// DELETE /users/me — delete account
router.delete('/me', async (req, res) => {
    try {
        await client_1.prisma.user.delete({ where: { id: req.uid } });
        res.json({ success: true });
    }
    catch (err) {
        res.status(500).json({ error: 'Failed to delete account' });
    }
});
exports.default = router;
//# sourceMappingURL=users.js.map