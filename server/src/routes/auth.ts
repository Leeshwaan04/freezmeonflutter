import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import { prisma } from '../db/client';
import { verifyGoogleToken } from '../services/google-auth';
import { verifyAppleToken } from '../services/apple-auth';
import { issueTokenPair, verifyRefreshToken, revokeRefreshToken } from '../services/jwt';

function safeUser(user: Record<string, any>) {
  const { passwordHash, ...safe } = user;
  return safe;
}

const router = Router();

// POST /auth/google
router.post('/google', async (req: Request, res: Response) => {
  try {
    const { idToken, displayName, photoUrl } = req.body;
    if (!idToken) { res.status(400).json({ error: 'idToken required' }); return; }

    const googleUser = await verifyGoogleToken(idToken);

    const user = await prisma.user.upsert({
      where: { id: googleUser.uid },
      update: { email: googleUser.email, lastActiveAt: new Date() },
      create: { id: googleUser.uid, email: googleUser.email },
    });

    const tokens = await issueTokenPair(user.id, user.email ?? undefined);
    let profile = await prisma.profile.findUnique({ where: { userId: user.id } });

    // Auto-populate profile with Google info if name is available
    const name = displayName || googleUser.name;
    if (name && !profile) {
      profile = await prisma.profile.create({
        data: {
          userId: user.id,
          name,
          age: 25, // placeholder until user sets it in onboarding
          imageUrl: photoUrl || googleUser.picture || null,
          interests: [],
        },
      });
    } else if (profile && (photoUrl || googleUser.picture) && !profile.imageUrl) {
      profile = await prisma.profile.update({
        where: { userId: user.id },
        data: { imageUrl: photoUrl || googleUser.picture },
      });
    }

    res.json({ ...tokens, user: safeUser({ ...user, displayName: name, photoUrl: photoUrl || googleUser.picture }), hasProfile: !!profile });
  } catch (err) {
    console.error('[auth/google]', err);
    res.status(401).json({ error: 'Google authentication failed' });
  }
});

// POST /auth/apple
router.post('/apple', async (req: Request, res: Response) => {
  try {
    const { identityToken } = req.body;
    if (!identityToken) { res.status(400).json({ error: 'identityToken required' }); return; }

    const appleUser = await verifyAppleToken(identityToken);

    const user = await prisma.user.upsert({
      where: { id: appleUser.uid },
      update: { email: appleUser.email, lastActiveAt: new Date() },
      create: { id: appleUser.uid, email: appleUser.email },
    });

    const tokens = await issueTokenPair(user.id, user.email ?? undefined);
    const profile = await prisma.profile.findUnique({ where: { userId: user.id } });

    res.json({ ...tokens, user: safeUser(user), hasProfile: !!profile });
  } catch (err) {
    console.error('[auth/apple]', err);
    res.status(401).json({ error: 'Apple authentication failed' });
  }
});

// POST /auth/email
router.post('/email', async (req: Request, res: Response) => {
  try {
    const { email, password, action } = req.body;
    if (!email || !password || !action) {
      res.status(400).json({ error: 'email, password, action required' }); return;
    }

    if (action === 'signup') {
      const existing = await prisma.user.findUnique({ where: { email } });
      if (existing) { res.status(409).json({ error: 'Email already registered' }); return; }

      const passwordHash = await bcrypt.hash(password, 12);
      const user = await prisma.user.create({ data: { email, passwordHash } });
      const tokens = await issueTokenPair(user.id, user.email ?? undefined);
      res.status(201).json({ ...tokens, user: safeUser(user), hasProfile: false });
    } else {
      const user = await prisma.user.findUnique({ where: { email } });
      if (!user?.passwordHash) { res.status(401).json({ error: 'Invalid credentials' }); return; }

      const valid = await bcrypt.compare(password, user.passwordHash);
      if (!valid) { res.status(401).json({ error: 'Invalid credentials' }); return; }

      await prisma.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } });
      const tokens = await issueTokenPair(user.id, user.email ?? undefined);
      const profile = await prisma.profile.findUnique({ where: { userId: user.id } });
      res.json({ ...tokens, user: safeUser(user), hasProfile: !!profile });
    }
  } catch (err) {
    console.error('[auth/email]', err);
    res.status(500).json({ error: 'Authentication failed' });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) { res.status(400).json({ error: 'refreshToken required' }); return; }

    const payload = verifyRefreshToken(refreshToken);
    const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!stored || stored.expiresAt < new Date()) {
      res.status(401).json({ error: 'Invalid or expired refresh token' }); return;
    }

    await revokeRefreshToken(refreshToken);
    const tokens = await issueTokenPair(payload.uid, payload.email);
    res.json(tokens);
  } catch {
    res.status(401).json({ error: 'Invalid refresh token' });
  }
});

// POST /auth/logout
router.post('/logout', async (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  if (refreshToken) await revokeRefreshToken(refreshToken);
  res.json({ success: true });
});

export default router;
