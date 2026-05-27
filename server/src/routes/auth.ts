import { Router, Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { logger } from '../services/logger';
import { prisma } from '../db/client';
import { verifyGoogleToken } from '../services/google-auth';
import { verifyAppleToken } from '../services/apple-auth';
import { issueTokenPair, verifyAccessToken, verifyRefreshToken, revokeRefreshToken, blacklistAccessToken } from '../services/jwt';
import { isValidEmail, isValidPassword } from '../utils/validate';
import { sendPasswordResetEmail, sendEmailVerificationEmail } from '../services/email';

function safeUser(user: Record<string, any>) {
  const { passwordHash, ...safe } = user;
  return safe;
}

const router = Router();

// POST /auth/google
router.post('/google', async (req: Request, res: Response) => {
  try {
    const { idToken, displayName, photoUrl } = req.body;
    if (!idToken) { res.status(400).json({ code: 'MISSING_FIELD', error: 'idToken required' }); return; }

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
    logger.error({ msg: 'auth_google_error', err });
    res.status(401).json({ code: 'AUTH_FAILED', error: 'Google authentication failed' });
  }
});

// POST /auth/apple
router.post('/apple', async (req: Request, res: Response) => {
  try {
    const { identityToken } = req.body;
    if (!identityToken) { res.status(400).json({ code: 'MISSING_FIELD', error: 'identityToken required' }); return; }

    const appleUser = await verifyAppleToken(identityToken);

    // Apple only sends email on first authorization — never overwrite with null.
    const user = await prisma.user.upsert({
      where: { id: appleUser.uid },
      update: {
        ...(appleUser.email ? { email: appleUser.email } : {}),
        lastActiveAt: new Date(),
      },
      create: { id: appleUser.uid, email: appleUser.email },
    });

    const tokens = await issueTokenPair(user.id, user.email ?? undefined);
    const profile = await prisma.profile.findUnique({ where: { userId: user.id } });

    res.json({ ...tokens, user: safeUser(user), hasProfile: !!profile });
  } catch (err) {
    logger.error({ msg: 'auth_apple_error', err });
    res.status(401).json({ code: 'AUTH_FAILED', error: 'Apple authentication failed' });
  }
});

// POST /auth/email
router.post('/email', async (req: Request, res: Response) => {
  try {
    const { email, password, action } = req.body;
    if (!email || !password || !action) {
      res.status(400).json({ code: 'MISSING_FIELD', error: 'email, password, action required' }); return;
    }
    if (!isValidEmail(email)) {
      res.status(400).json({ code: 'INVALID_EMAIL', error: 'Invalid email address' }); return;
    }
    if (!isValidPassword(password)) {
      res.status(400).json({ code: 'INVALID_PASSWORD', error: 'Password must be 8–128 characters' }); return;
    }
    // Accept both 'login' and 'signin' (Flutter sends 'signin')
    const normalizedAction = action === 'signin' ? 'login' : action;
    if (normalizedAction !== 'signup' && normalizedAction !== 'login') {
      res.status(400).json({ code: 'INVALID_ACTION', error: 'action must be signup or login' }); return;
    }

    if (normalizedAction === 'signup') {
      const existing = await prisma.user.findUnique({ where: { email } });
      if (existing) { res.status(409).json({ code: 'EMAIL_EXISTS', error: 'Email already registered' }); return; }

      const passwordHash = await bcrypt.hash(password, 12);
      const user = await prisma.user.create({ data: { email, passwordHash } });
      const tokens = await issueTokenPair(user.id, user.email ?? undefined);
      res.status(201).json({ ...tokens, user: safeUser(user), hasProfile: false });
    } else {
      const user = await prisma.user.findUnique({ where: { email } });
      if (!user?.passwordHash) { res.status(401).json({ code: 'INVALID_CREDENTIALS', error: 'Invalid credentials' }); return; }

      const valid = await bcrypt.compare(password, user.passwordHash);
      if (!valid) { res.status(401).json({ code: 'INVALID_CREDENTIALS', error: 'Invalid credentials' }); return; }

      await prisma.user.update({ where: { id: user.id }, data: { lastActiveAt: new Date() } });
      const tokens = await issueTokenPair(user.id, user.email ?? undefined);
      const profile = await prisma.profile.findUnique({ where: { userId: user.id } });
      res.json({ ...tokens, user: safeUser(user), hasProfile: !!profile });
    }
  } catch (err) {
    logger.error({ msg: 'auth_email_error', err });
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Authentication failed' });
  }
});

// POST /auth/refresh
router.post('/refresh', async (req: Request, res: Response) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) { res.status(400).json({ code: 'MISSING_FIELD', error: 'refreshToken required' }); return; }

    const payload = verifyRefreshToken(refreshToken);
    const stored = await prisma.refreshToken.findUnique({ where: { token: refreshToken } });
    if (!stored || stored.expiresAt < new Date()) {
      res.status(401).json({ code: 'TOKEN_EXPIRED', error: 'Invalid or expired refresh token' }); return;
    }

    await revokeRefreshToken(refreshToken);
    const tokens = await issueTokenPair(payload.uid, payload.email);
    res.json(tokens);
  } catch {
    res.status(401).json({ code: 'INVALID_TOKEN', error: 'Invalid refresh token' });
  }
});

// POST /auth/logout
router.post('/logout', async (req: Request, res: Response) => {
  const { refreshToken } = req.body;
  // Revoke refresh token from DB
  if (refreshToken) await revokeRefreshToken(refreshToken);
  // Blacklist the current access token so it can't be reused after logout
  const authHeader = req.headers.authorization;
  if (authHeader?.startsWith('Bearer ')) {
    await blacklistAccessToken(authHeader.slice(7));
  }
  res.json({ success: true });
});

// POST /auth/forgot-password — send password reset email
router.post('/forgot-password', async (req: Request, res: Response) => {
  try {
    const { email } = req.body;
    if (!email || !isValidEmail(email)) {
      res.status(400).json({ error: 'Valid email required' }); return;
    }

    const user = await prisma.user.findUnique({ where: { email } });
    // Always return 200 to prevent email enumeration
    if (!user || !user.passwordHash) {
      res.json({ success: true, message: 'If that email exists, a reset link has been sent.' }); return;
    }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 60 * 60 * 1000); // 1 hour

    // Invalidate any existing tokens for this user
    await prisma.passwordResetToken.deleteMany({ where: { userId: user.id } });
    await prisma.passwordResetToken.create({ data: { userId: user.id, token, expiresAt } });

    await sendPasswordResetEmail(email, token);
    res.json({ success: true, message: 'If that email exists, a reset link has been sent.' });
  } catch (err) {
    logger.error({ msg: 'auth_forgot_password_error', err });
    res.status(500).json({ error: 'Failed to process request' });
  }
});

// POST /auth/reset-password — set new password using reset token
router.post('/reset-password', async (req: Request, res: Response) => {
  try {
    const { token, newPassword } = req.body;
    if (!token || !newPassword) {
      res.status(400).json({ error: 'token and newPassword required' }); return;
    }
    if (!isValidPassword(newPassword)) {
      res.status(400).json({ error: 'Password must be 8–128 characters' }); return;
    }

    const resetToken = await prisma.passwordResetToken.findUnique({ where: { token } });
    if (!resetToken || resetToken.used || resetToken.expiresAt < new Date()) {
      res.status(400).json({ error: 'Invalid or expired reset token' }); return;
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await prisma.$transaction([
      prisma.user.update({ where: { id: resetToken.userId }, data: { passwordHash } }),
      prisma.passwordResetToken.update({ where: { id: resetToken.id }, data: { used: true } }),
      // Revoke all refresh tokens on password reset (security best practice)
      prisma.refreshToken.deleteMany({ where: { userId: resetToken.userId } }),
    ]);

    res.json({ success: true, message: 'Password updated. Please log in again.' });
  } catch (err) {
    logger.error({ msg: 'auth_reset_password_error', err });
    res.status(500).json({ error: 'Failed to reset password' });
  }
});

// POST /auth/send-verification — send email verification link
router.post('/send-verification', async (req: Request, res: Response) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Authentication required' }); return;
    }

    let uid: string;
    try {
      const payload = verifyAccessToken(authHeader.slice(7));
      uid = payload.uid;
    } catch {
      res.status(401).json({ error: 'Invalid token' }); return;
    }

    const user = await prisma.user.findUnique({ where: { id: uid } });
    if (!user?.email) { res.status(400).json({ error: 'No email on account' }); return; }
    if (user.emailVerified) { res.json({ success: true, message: 'Email already verified' }); return; }

    const token = crypto.randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000); // 24 hours

    await prisma.emailVerificationToken.deleteMany({ where: { userId: uid } });
    await prisma.emailVerificationToken.create({ data: { userId: uid, token, expiresAt } });

    await sendEmailVerificationEmail(user.email, token);
    res.json({ success: true, message: 'Verification email sent' });
  } catch (err) {
    logger.error({ msg: 'auth_send_verification_error', err });
    res.status(500).json({ error: 'Failed to send verification email' });
  }
});

// GET /auth/verify-email?token=... — confirm email ownership
router.get('/verify-email', async (req: Request, res: Response) => {
  try {
    const { token } = req.query;
    if (!token || typeof token !== 'string') {
      res.status(400).send('Invalid verification link.'); return;
    }

    const verifyToken = await prisma.emailVerificationToken.findUnique({ where: { token } });
    if (!verifyToken || verifyToken.expiresAt < new Date()) {
      res.status(400).send('This verification link has expired. Please request a new one.'); return;
    }

    await prisma.$transaction([
      prisma.user.update({ where: { id: verifyToken.userId }, data: { emailVerified: true } }),
      prisma.emailVerificationToken.delete({ where: { id: verifyToken.id } }),
    ]);

    // Redirect to app deep link or show success page
    res.redirect(`freezme://email-verified`);
  } catch (err) {
    logger.error({ msg: 'auth_verify_email_error', err });
    res.status(500).send('Verification failed. Please try again.');
  }
});

export default router;
