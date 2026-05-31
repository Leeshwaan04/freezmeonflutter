import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { prisma } from '../db/client';
import { v4 as uuidv4 } from 'uuid';

const JWT_SECRET = process.env.JWT_SECRET!;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN ?? '15m';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN ?? '30d';

// Hash refresh tokens before storing — DB leak should not expose usable tokens.
export function hashRefreshToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export interface JwtPayload {
  uid: string;
  email?: string;
  jti?: string;
}

export function signAccessToken(payload: JwtPayload): string {
  const jti = uuidv4();
  return jwt.sign({ ...payload, jti }, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN } as jwt.SignOptions);
}

export function signRefreshToken(payload: JwtPayload): string {
  return jwt.sign(payload, JWT_REFRESH_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN } as jwt.SignOptions);
}

export function verifyAccessToken(token: string): JwtPayload {
  return jwt.verify(token, JWT_SECRET, { algorithms: ['HS256'] }) as JwtPayload;
}

export function verifyRefreshToken(token: string): JwtPayload {
  return jwt.verify(token, JWT_REFRESH_SECRET, { algorithms: ['HS256'] }) as JwtPayload;
}

export async function issueTokenPair(uid: string, email?: string): Promise<{ accessToken: string; refreshToken: string }> {
  const payload: JwtPayload = { uid, email };
  const accessToken = signAccessToken(payload);
  const refreshToken = signRefreshToken(payload);

  const expiresAt = new Date();
  expiresAt.setDate(expiresAt.getDate() + 30);

  await prisma.refreshToken.create({
    data: {
      userId: uid,
      token: hashRefreshToken(refreshToken),
      expiresAt,
    },
  });

  return { accessToken, refreshToken };
}

export async function revokeRefreshToken(token: string): Promise<void> {
  await prisma.refreshToken.deleteMany({ where: { token: hashRefreshToken(token) } });
}

// Atomic rotate: delete the old refresh token row and report whether it actually existed.
// Returns true if the token was valid and is now revoked; false if it was already revoked
// (refresh-token reuse — caller should treat as compromised and revoke the family).
export async function rotateRefreshToken(token: string, uid: string): Promise<boolean> {
  const hash = hashRefreshToken(token);
  const result = await prisma.refreshToken.deleteMany({ where: { token: hash, userId: uid } });
  return result.count > 0;
}

// Revoke ALL refresh tokens for a user (used when reuse is detected — token family compromise).
export async function revokeAllUserRefreshTokens(uid: string): Promise<void> {
  await prisma.refreshToken.deleteMany({ where: { userId: uid } });
}

// Blacklist an access token by its jti so it cannot be reused after logout.
// expiresAt is copied from the JWT exp so the row can be cleaned up after expiry.
export async function blacklistAccessToken(token: string): Promise<void> {
  try {
    const decoded = jwt.decode(token) as any;
    if (!decoded?.jti || !decoded?.exp) return;
    const expiresAt = new Date(decoded.exp * 1000);
    await prisma.tokenBlacklist.upsert({
      where: { jti: decoded.jti },
      update: {},
      create: { jti: decoded.jti, expiresAt },
    });
  } catch {
    // Best-effort — don't fail logout if blacklist write fails
  }
}

export async function isTokenBlacklisted(jti: string): Promise<boolean> {
  const entry = await prisma.tokenBlacklist.findUnique({ where: { jti } });
  return entry !== null;
}
