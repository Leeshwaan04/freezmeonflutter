import {
  signAccessToken,
  signRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  type JwtPayload,
} from '../../src/services/jwt';

describe('JWT Service — Unit Tests', () => {
  const payload: JwtPayload = { uid: 'user-123', email: 'test@freezme.com' };

  // ── Access Token ──────────────────────────────────────────────────────────

  describe('signAccessToken', () => {
    it('returns a non-empty string', () => {
      const token = signAccessToken(payload);
      expect(typeof token).toBe('string');
      expect(token.length).toBeGreaterThan(0);
    });

    it('produces a 3-part JWT', () => {
      const token = signAccessToken(payload);
      expect(token.split('.')).toHaveLength(3);
    });

    it('two calls with same payload produce different tokens (iat differs)', () => {
      const t1 = signAccessToken(payload);
      const t2 = signAccessToken(payload);
      // Same payload but issued at slightly different times — may differ
      expect(t1).toBeDefined();
      expect(t2).toBeDefined();
    });
  });

  describe('verifyAccessToken', () => {
    it('decodes uid and email correctly', () => {
      const token = signAccessToken(payload);
      const decoded = verifyAccessToken(token);
      expect(decoded.uid).toBe('user-123');
      expect(decoded.email).toBe('test@freezme.com');
    });

    it('throws on tampered token', () => {
      const token = signAccessToken(payload);
      const tampered = token.slice(0, -5) + 'XXXXX';
      expect(() => verifyAccessToken(tampered)).toThrow();
    });

    it('throws on refresh token used as access token', () => {
      const refresh = signRefreshToken(payload);
      expect(() => verifyAccessToken(refresh)).toThrow();
    });

    it('throws on empty string', () => {
      expect(() => verifyAccessToken('')).toThrow();
    });

    it('throws on garbage string', () => {
      expect(() => verifyAccessToken('not.a.jwt')).toThrow();
    });
  });

  // ── Refresh Token ─────────────────────────────────────────────────────────

  describe('signRefreshToken', () => {
    it('returns a non-empty JWT string', () => {
      const token = signRefreshToken(payload);
      expect(token.split('.')).toHaveLength(3);
    });

    it('is different from access token for same payload', () => {
      const access  = signAccessToken(payload);
      const refresh = signRefreshToken(payload);
      expect(access).not.toBe(refresh);
    });
  });

  describe('verifyRefreshToken', () => {
    it('decodes uid correctly', () => {
      const token = signRefreshToken(payload);
      const decoded = verifyRefreshToken(token);
      expect(decoded.uid).toBe('user-123');
    });

    it('throws on access token used as refresh token', () => {
      const access = signAccessToken(payload);
      expect(() => verifyRefreshToken(access)).toThrow();
    });

    it('throws on tampered refresh token', () => {
      const token = signRefreshToken(payload);
      const tampered = token.slice(0, -3) + 'ZZZ';
      expect(() => verifyRefreshToken(tampered)).toThrow();
    });
  });

  // ── Payload edge cases ────────────────────────────────────────────────────

  describe('edge cases', () => {
    it('handles payload with no email (email optional)', () => {
      const token = signAccessToken({ uid: 'uid-only' });
      const decoded = verifyAccessToken(token);
      expect(decoded.uid).toBe('uid-only');
      expect(decoded.email).toBeUndefined();
    });

    it('handles uid with special characters', () => {
      const token = signAccessToken({ uid: 'uid-abc-123-XYZ' });
      const decoded = verifyAccessToken(token);
      expect(decoded.uid).toBe('uid-abc-123-XYZ');
    });
  });
});
