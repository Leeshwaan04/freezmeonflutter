import { Request, Response, NextFunction } from 'express';
import { verifyAccessToken, isTokenBlacklisted, JwtPayload } from '../services/jwt';

declare global {
  namespace Express {
    interface Request {
      uid: string;
      jwtPayload: JwtPayload;
    }
  }
}

export function requireAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    res.status(401).json({ error: 'Missing or invalid Authorization header' });
    return;
  }

  const token = authHeader.slice(7);
  let payload: JwtPayload;
  try {
    payload = verifyAccessToken(token);
  } catch {
    res.status(401).json({ error: 'Invalid or expired token' });
    return;
  }

  if (!payload.jti) {
    // Legacy tokens without jti — still accepted
    req.uid = payload.uid;
    req.jwtPayload = payload;
    next();
    return;
  }

  // Async blacklist check — fail-closed: if DB is unavailable, reject the request
  // (security > availability: a revoked token must never be accepted)
  isTokenBlacklisted(payload.jti)
    .then((blacklisted) => {
      if (blacklisted) {
        res.status(401).json({ error: 'Token has been revoked' });
        return;
      }
      req.uid = payload.uid;
      req.jwtPayload = payload;
      next();
    })
    .catch(() => {
      res.status(503).json({ error: 'Authentication service temporarily unavailable. Please retry.' });
    });
}
