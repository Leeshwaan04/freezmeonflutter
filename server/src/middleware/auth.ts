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
    // All access tokens issued by this server include a jti. A missing jti means
    // the token was either forged or issued under a previous code path that no
    // longer applies. Reject — the user can simply re-authenticate.
    res.status(401).json({ error: 'Invalid token — please log in again' });
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
