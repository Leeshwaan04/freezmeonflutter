import jwt from 'jsonwebtoken';
import { prisma } from '../db/client';
import { v4 as uuidv4 } from 'uuid';

const JWT_SECRET = process.env.JWT_SECRET!;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET!;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN ?? '15m';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN ?? '30d';

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
      token: refreshToken,
      expiresAt,
    },
  });

  return { accessToken, refreshToken };
}

export async function revokeRefreshToken(token: string): Promise<void> {
  await prisma.refreshToken.deleteMany({ where: { token } });
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
