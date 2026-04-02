"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const client_1 = require("../db/client");
const google_auth_1 = require("../services/google-auth");
const apple_auth_1 = require("../services/apple-auth");
const jwt_1 = require("../services/jwt");
const router = (0, express_1.Router)();
// POST /auth/google
router.post('/google', async (req, res) => {
    try {
        const { idToken } = req.body;
        if (!idToken) {
            res.status(400).json({ error: 'idToken required' });
            return;
        }
        const googleUser = await (0, google_auth_1.verifyGoogleToken)(idToken);
        const user = await client_1.prisma.user.upsert({
            where: { id: googleUser.uid },
            update: { email: googleUser.email, lastActiveAt: new Date() },
            create: { id: googleUser.uid, email: googleUser.email },
        });
        const tokens = await (0, jwt_1.issueTokenPair)(user.id, user.email ?? undefined);
        const profile = await client_1.prisma.profile.findUnique({ where: { userId: user.id } });
        res.json({ ...tokens, user, hasProfile: !!profile });
    }
    catch (err) {
        console.error('[auth/google]', err);
        res.status(401).json({ error: 'Google authentication failed' });
    }
});
// POST /auth/apple
router.post('/apple', async (req, res) => {
    try {
        const { identityToken } = req.body;
        if (!identityToken) {
            res.status(400).json({ error: 'identityToken required' });
            return;
        }
        const appleUser = await (0, apple_auth_1.verifyAppleToken)(identityToken);
        const user = await client_1.prisma.user.upsert({
            where: { id: appleUser.uid },
            update: { email: appleUser.email, lastActiveAt: new Date() },
            create: { id: appleUser.uid, email: appleUser.email },
        });
        const tokens = await (0, jwt_1.issueTokenPair)(user.id, user.email ?? undefined);
        const profile = await client_1.prisma.profile.findUnique({ where: { userId: user.id } });
        res.json({ ...tokens, user, hasProfile: !!profile });
    }
    catch (err) {
        console.error('[auth/apple]', err);
        res.status(401).json({ error: 'Apple authentication failed' });
    }
});
// POST /auth/email
router.post('/email', async (req, res) => {
    try {
        const { email, password, action } = req.body;
        if (!email || !password || !action) {
            res.status(400).json({ error: 'email, password, action required' });
            return;
        }
        if (action === 'signup') {
            const existing = await client_1.prisma.user.findUnique({ where: { email } });
            if (existing) {
                res.status(409).json({ error: 'Email already registered' });
                return;
            }
            const passwordHash = await bcryptjs_1.default.hash(password, 12);
            const user = await client_1.prisma.user.create({ data: { email, passwordHash } });
            const tokens = await (0, jwt_1.issueTokenPair)(user.id, user.email ?? undefined);
            res.status(201).json({ ...tokens, user, hasProfile: false });
        }
        else {
            const user = await client_1.prisma.user.findUnique({ where: { email } });
            if (!user?.passwordHash) {
                res.status(401).json({ error: 'Invalid credentials' });
                return;
            }
            const valid = await bcryptjs_1.default.compare(password, user.passwordHash);
            if (!valid) {
                res.status(401).json({ error: 'Invalid credentials' });
                return;
            }
            await client_1.prisma.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } });
            const tokens = await (0, jwt_1.issueTokenPair)(user.id, user.email ?? undefined);
            const profile = await client_1.prisma.profile.findUnique({ where: { userId: user.id } });
            res.json({ ...tokens, user, hasProfile: !!profile });
        }
    }
    catch (err) {
        console.error('[auth/email]', err);
        res.status(500).json({ error: 'Authentication failed' });
    }
});
// POST /auth/refresh
router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;
        if (!refreshToken) {
            res.status(400).json({ error: 'refreshToken required' });
            return;
        }
        const payload = (0, jwt_1.verifyRefreshToken)(refreshToken);
        const stored = await client_1.prisma.refreshToken.findUnique({ where: { token: refreshToken } });
        if (!stored || stored.expiresAt < new Date()) {
            res.status(401).json({ error: 'Invalid or expired refresh token' });
            return;
        }
        await (0, jwt_1.revokeRefreshToken)(refreshToken);
        const tokens = await (0, jwt_1.issueTokenPair)(payload.uid, payload.email);
        res.json(tokens);
    }
    catch {
        res.status(401).json({ error: 'Invalid refresh token' });
    }
});
// POST /auth/logout
router.post('/logout', async (req, res) => {
    const { refreshToken } = req.body;
    if (refreshToken)
        await (0, jwt_1.revokeRefreshToken)(refreshToken);
    res.json({ success: true });
});
exports.default = router;
//# sourceMappingURL=auth.js.map