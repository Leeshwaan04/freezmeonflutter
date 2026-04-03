import bcrypt from 'bcryptjs';

describe('Auth Helpers — Unit Tests (bcrypt)', () => {

  describe('password hashing', () => {
    it('hash is different from plaintext', async () => {
      const hash = await bcrypt.hash('MyPassword123!', 10);
      expect(hash).not.toBe('MyPassword123!');
    });

    it('correct password passes verification', async () => {
      const hash = await bcrypt.hash('CorrectHorse', 10);
      const valid = await bcrypt.compare('CorrectHorse', hash);
      expect(valid).toBe(true);
    });

    it('wrong password fails verification', async () => {
      const hash = await bcrypt.hash('CorrectHorse', 10);
      const valid = await bcrypt.compare('WrongPassword', hash);
      expect(valid).toBe(false);
    });

    it('two hashes of same password are different (salt)', async () => {
      const h1 = await bcrypt.hash('SamePass', 10);
      const h2 = await bcrypt.hash('SamePass', 10);
      expect(h1).not.toBe(h2);
      // But both verify correctly
      expect(await bcrypt.compare('SamePass', h1)).toBe(true);
      expect(await bcrypt.compare('SamePass', h2)).toBe(true);
    });

    it('empty string can be hashed and verified', async () => {
      const hash = await bcrypt.hash('', 10);
      expect(await bcrypt.compare('', hash)).toBe(true);
      expect(await bcrypt.compare('notempty', hash)).toBe(false);
    });

    it('very long password works', async () => {
      const long = 'a'.repeat(200);
      const hash = await bcrypt.hash(long, 10);
      expect(await bcrypt.compare(long, hash)).toBe(true);
    });
  });

  describe('safeUser helper (passwordHash stripping)', () => {
    it('strips passwordHash from user object', () => {
      function safeUser(user: Record<string, any>) {
        const { passwordHash, ...safe } = user;
        return safe;
      }
      const user = {
        id: 'uid-1',
        email: 'a@b.com',
        passwordHash: '$2a$12$abc',
        fcmToken: null,
        status: 'active',
      };
      const safe = safeUser(user);
      expect(safe).not.toHaveProperty('passwordHash');
      expect(safe.id).toBe('uid-1');
      expect(safe.email).toBe('a@b.com');
    });

    it('does not throw when passwordHash is absent', () => {
      function safeUser(user: Record<string, any>) {
        const { passwordHash, ...safe } = user;
        return safe;
      }
      const user = { id: 'uid-2', email: 'b@c.com' };
      expect(() => safeUser(user)).not.toThrow();
    });
  });
});
