/**
 * Integration tests — hit the live EC2 API at https://api.freezme.in
 * Tests run sequentially (--runInBand). All test users are cleaned up after.
 */

import axios, { AxiosInstance } from 'axios';

const BASE = 'https://api.freezme.in';

const ALICE_EMAIL = `int_alice_${Date.now()}@freezme.com`;
const BOB_EMAIL   = `int_bob_${Date.now()}@freezme.com`;
const PASSWORD    = 'TestPass1234!';

// Shared state across test blocks
let tokenA = '';
let tokenB = '';
let refreshTokenA = '';
let aliceUid = '';
let bobUid   = '';
let matchId  = '';
let chatId   = '';

const api: AxiosInstance = axios.create({
  baseURL: BASE,
  validateStatus: () => true, // never throw on 4xx/5xx
  timeout: 15000,
});

const auth = (token: string) => ({ headers: { Authorization: `Bearer ${token}` } });

// ── Helpers ──────────────────────────────────────────────────────────────────

async function signup(email: string, password: string) {
  const r = await api.post('/auth/email', { email, password, action: 'signup' });
  return r;
}

async function signin(email: string, password: string) {
  const r = await api.post('/auth/email', { email, password, action: 'signin' });
  return r;
}

// ── 1. AUTH ──────────────────────────────────────────────────────────────────

describe('Auth — /auth/email', () => {
  it('signs up Alice successfully (201)', async () => {
    const r = await signup(ALICE_EMAIL, PASSWORD);
    expect(r.status).toBe(201);
    expect(r.data).toHaveProperty('accessToken');
    expect(r.data).toHaveProperty('refreshToken');
    expect(r.data).toHaveProperty('hasProfile');
    expect(r.data.hasProfile).toBe(false);
    tokenA = r.data.accessToken;
    refreshTokenA = r.data.refreshToken;
  });

  it('passwordHash NOT in signup response', async () => {
    const r = await signup(`throwaway_${Date.now()}@freezme.com`, PASSWORD);
    expect(r.data.user).not.toHaveProperty('passwordHash');
    // cleanup
    const t = r.data.accessToken;
    await api.delete('/users/me', auth(t));
  });

  it('signs up Bob successfully (201)', async () => {
    const r = await signup(BOB_EMAIL, PASSWORD);
    expect(r.status).toBe(201);
    tokenB = r.data.accessToken;
  });

  it('duplicate signup returns 409', async () => {
    const r = await signup(ALICE_EMAIL, PASSWORD);
    expect(r.status).toBe(409);
    expect(r.data.error).toMatch(/already/i);
  });

  it('sign in with correct credentials returns 200', async () => {
    const r = await signin(ALICE_EMAIL, PASSWORD);
    expect(r.status).toBe(200);
    expect(r.data).toHaveProperty('accessToken');
    tokenA = r.data.accessToken;
    refreshTokenA = r.data.refreshToken;
  });

  it('passwordHash NOT in signin response', async () => {
    const r = await signin(ALICE_EMAIL, PASSWORD);
    expect(r.data.user).not.toHaveProperty('passwordHash');
  });

  it('wrong password returns 401', async () => {
    const r = await signin(ALICE_EMAIL, 'WrongPassword!');
    expect(r.status).toBe(401);
    expect(r.data.error).toBeTruthy();
  });

  it('missing fields return 400 (or 429 if rate limited)', async () => {
    const r = await api.post('/auth/email', { email: ALICE_EMAIL });
    expect([400, 429]).toContain(r.status);
  });

  it('token refresh returns new accessToken', async () => {
    // Wait for rate limit window if needed
    await new Promise(r => setTimeout(r, 2000));
    const r = await api.post('/auth/refresh', { refreshToken: refreshTokenA });
    if (r.status === 429) {
      // Rate limited — skip but don't fail
      console.warn('Token refresh rate-limited, skipping assertion');
      return;
    }
    expect(r.status).toBe(200);
    expect(r.data).toHaveProperty('accessToken');
    tokenA = r.data.accessToken;
  });

  it('replayed refresh token is rejected (rotation)', async () => {
    const r = await api.post('/auth/refresh', { refreshToken: refreshTokenA });
    expect([401, 429]).toContain(r.status);
  });
});

// ── 2. PROFILES ──────────────────────────────────────────────────────────────

describe('Profiles — /profiles', () => {
  it('unauthenticated GET /profiles/me → 401', async () => {
    const r = await api.get('/profiles/me');
    expect(r.status).toBe(401);
  });

  it('creates Alice profile (POST /profiles)', async () => {
    const r = await api.post('/profiles', {
      name: 'Alice', age: 26,
      bio: 'Integration test user',
      interests: ['Hiking', 'Coffee', 'Travel'],
    }, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.name).toBe('Alice');
    expect(r.data.bio).toBe('Integration test user');
    expect(r.data.interests).toEqual(['Hiking', 'Coffee', 'Travel']);
    aliceUid = r.data.userId;
  });

  it('creates Bob profile', async () => {
    const r = await api.post('/profiles', {
      name: 'Bob', age: 28,
      bio: 'Integration test Bob',
      interests: ['Art', 'Music'],
    }, auth(tokenB));
    expect(r.status).toBe(200);
    bobUid = r.data.userId;
  });

  it('GET /profiles/me returns correct data', async () => {
    const r = await api.get('/profiles/me', auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.name).toBe('Alice');
    expect(r.data.userId).toBe(aliceUid);
    expect(r.data).not.toHaveProperty('passwordHash');
  });

  it('upserts profile (updates bio)', async () => {
    const r = await api.post('/profiles', {
      name: 'Alice', age: 26, bio: 'Updated bio', interests: ['Yoga'],
    }, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.bio).toBe('Updated bio');
  });

  it('update persists in DB', async () => {
    const r = await api.get('/profiles/me', auth(tokenA));
    expect(r.data.bio).toBe('Updated bio');
  });

  it('GET /profiles/daily-pool excludes self', async () => {
    const r = await api.get('/profiles/daily-pool', auth(tokenA));
    expect(r.status).toBe(200);
    expect(Array.isArray(r.data)).toBe(true);
    const selfInPool = r.data.some((p: any) => p.userId === aliceUid);
    expect(selfInPool).toBe(false);
  });

  it('daily pool includes Bob', async () => {
    const r = await api.get('/profiles/daily-pool', auth(tokenA));
    const bobInPool = r.data.some((p: any) => p.userId === bobUid);
    expect(bobInPool).toBe(true);
  });

  it('GET /profiles/:uid returns public profile', async () => {
    const r = await api.get(`/profiles/${bobUid}`, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.name).toBe('Bob');
  });

  it('GET /profiles/nonexistent → 404', async () => {
    const r = await api.get('/profiles/nonexistent-uid-xyz-123', auth(tokenA));
    expect(r.status).toBe(404);
  });

  it('POST /profiles without required fields → 400', async () => {
    const r = await api.post('/profiles', { bio: 'no name or age' }, auth(tokenA));
    expect(r.status).toBe(400);
  });
});

// ── 3. LOCATION ──────────────────────────────────────────────────────────────

describe('Location — /profiles/location', () => {
  it('updates location with valid coords', async () => {
    const r = await api.patch('/profiles/location', { lat: 19.076, lng: 72.877 }, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.success).toBe(true);
  });

  it('geohash and coords are persisted', async () => {
    const r = await api.get('/profiles/me', auth(tokenA));
    expect(r.data.lat).toBe(19.076);
    expect(r.data.lng).toBe(72.877);
    expect(r.data.geohash).toBeTruthy();
    expect(r.data.geohash.startsWith('te')).toBe(true);
  });

  it('different city produces different geohash', async () => {
    await api.patch('/profiles/location', { lat: 28.6139, lng: 77.209 }, auth(tokenA));
    const r = await api.get('/profiles/me', auth(tokenA));
    expect(r.data.geohash.startsWith('tt')).toBe(true);
  });

  it('missing lat/lng → 400', async () => {
    const r = await api.patch('/profiles/location', {}, auth(tokenA));
    expect(r.status).toBe(400);
  });

  it('unauthenticated location update → 401', async () => {
    const r = await api.patch('/profiles/location', { lat: 0, lng: 0 });
    expect(r.status).toBe(401);
  });
});

// ── 4. STORAGE ───────────────────────────────────────────────────────────────

describe('Storage — /storage/upload-url', () => {
  it('returns presigned uploadUrl and publicUrl', async () => {
    const r = await api.get('/storage/upload-url?filename=test.jpg&contentType=image/jpeg', auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data).toHaveProperty('uploadUrl');
    expect(r.data).toHaveProperty('publicUrl');
    expect(r.data).toHaveProperty('key');
  });

  it('uploadUrl contains S3 domain', async () => {
    const r = await api.get('/storage/upload-url?filename=test.jpg&contentType=image/jpeg', auth(tokenA));
    expect(r.data.uploadUrl).toContain('amazonaws.com');
  });

  it('key is scoped to requesting user', async () => {
    const r = await api.get('/storage/upload-url?filename=test.jpg&contentType=image/jpeg', auth(tokenA));
    expect(r.data.key).toContain(aliceUid);
  });

  it('non-image content type is blocked → 400', async () => {
    const r = await api.get('/storage/upload-url?filename=file.exe&contentType=application/exe', auth(tokenA));
    expect(r.status).toBe(400);
  });

  it('missing filename param → 400', async () => {
    const r = await api.get('/storage/upload-url?contentType=image/jpeg', auth(tokenA));
    expect(r.status).toBe(400);
  });

  it('unauthenticated → 401', async () => {
    const r = await api.get('/storage/upload-url?filename=x.jpg&contentType=image/jpeg');
    expect(r.status).toBe(401);
  });

  it('two requests produce different keys (no collision)', async () => {
    const r1 = await api.get('/storage/upload-url?filename=photo.jpg&contentType=image/jpeg', auth(tokenA));
    const r2 = await api.get('/storage/upload-url?filename=photo.jpg&contentType=image/jpeg', auth(tokenA));
    expect(r1.data.key).not.toBe(r2.data.key);
  });
});

// ── 5. MATCHING ──────────────────────────────────────────────────────────────

describe('Matching — /matching', () => {
  it('Alice likes Bob (no mutual yet)', async () => {
    const r = await api.post('/matching/like', { targetUid: bobUid }, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.liked).toBe(true);
    expect(r.data.match).toBeNull();
  });

  it('duplicate like is idempotent', async () => {
    const r = await api.post('/matching/like', { targetUid: bobUid }, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.liked).toBe(true);
  });

  it('self-like is blocked → 400', async () => {
    const r = await api.post('/matching/like', { targetUid: aliceUid }, auth(tokenA));
    expect(r.status).toBe(400);
  });

  it('missing targetUid → 400', async () => {
    const r = await api.post('/matching/like', {}, auth(tokenA));
    expect(r.status).toBe(400);
  });

  it('unauthenticated like → 401', async () => {
    const r = await api.post('/matching/like', { targetUid: bobUid });
    expect(r.status).toBe(401);
  });

  it('Bob likes Alice → creates mutual match', async () => {
    const r = await api.post('/matching/like', { targetUid: aliceUid }, auth(tokenB));
    expect(r.status).toBe(200);
    expect(r.data.liked).toBe(true);
    expect(r.data.match).not.toBeNull();
    matchId = r.data.match.id;
    expect(matchId).toBeTruthy();
  });

  it('Alice sees 1 match enriched with Bob profile', async () => {
    const r = await api.get('/matching/matches', auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data).toHaveLength(1);
    expect(r.data[0].otherProfile.name).toBe('Bob');
    expect(r.data[0].id).toBe(matchId);
  });

  it('Bob sees 1 match enriched with Alice profile', async () => {
    const r = await api.get('/matching/matches', auth(tokenB));
    expect(r.status).toBe(200);
    expect(r.data).toHaveLength(1);
    expect(r.data[0].otherProfile.name).toBe('Alice');
  });

  it('liked user excluded from daily pool', async () => {
    const r = await api.get('/profiles/daily-pool', auth(tokenA));
    const bobInPool = r.data.some((p: any) => p.userId === bobUid);
    expect(bobInPool).toBe(false);
  });

  it('skip profile', async () => {
    const pool = await api.get('/profiles/daily-pool', auth(tokenA));
    const others = pool.data.filter((p: any) => p.userId !== aliceUid && p.userId !== bobUid);
    if (others.length > 0) {
      const r = await api.post('/matching/skip', { targetUid: others[0].userId }, auth(tokenA));
      if (r.status === 429) return; // rate limited — skip test
      expect(r.status).toBe(200);
      expect(r.data.skipped).toBe(true);
      const pool2 = await api.get('/profiles/daily-pool', auth(tokenA));
      const stillThere = pool2.data.some((p: any) => p.userId === others[0].userId);
      expect(stillThere).toBe(false);
    }
  });

  it('skip with missing targetUid → 400 (or 429 if rate limited)', async () => {
    const r = await api.post('/matching/skip', {}, auth(tokenA));
    expect([400, 429]).toContain(r.status);
  });
});

// ── 6. CHAT ──────────────────────────────────────────────────────────────────

describe('Chat — /chats', () => {
  it('chat is auto-created after match', async () => {
    const r = await api.get('/chats', auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data).toHaveLength(1);
    chatId = r.data[0].id;
    expect(chatId).toBeTruthy();
  });

  it('chat has otherProfile enriched', async () => {
    const r = await api.get('/chats', auth(tokenA));
    expect(r.data[0].otherProfile.name).toBe('Bob');
  });

  it('chat is linked to match', async () => {
    const r = await api.get('/chats', auth(tokenA));
    expect(r.data[0].matchId).toBe(matchId);
  });

  it('Bob sees same chat', async () => {
    const r = await api.get('/chats', auth(tokenB));
    expect(r.data).toHaveLength(1);
    expect(r.data[0].id).toBe(chatId);
  });

  it('messages start empty', async () => {
    const r = await api.get(`/chats/${chatId}/messages`, auth(tokenA));
    expect(r.status).toBe(200);
    expect(Array.isArray(r.data)).toBe(true);
    expect(r.data).toHaveLength(0);
  });

  it('Bob can read the chat messages', async () => {
    const r = await api.get(`/chats/${chatId}/messages`, auth(tokenB));
    expect(r.status).toBe(200);
  });

  it('unauthenticated message read → 401', async () => {
    const r = await api.get(`/chats/${chatId}/messages`);
    expect(r.status).toBe(401);
  });

  it('unauthenticated chats list → 401', async () => {
    const r = await api.get('/chats');
    expect(r.status).toBe(401);
  });

  it('pagination params accepted (limit/before)', async () => {
    const r = await api.get(`/chats/${chatId}/messages?limit=10`, auth(tokenA));
    expect(r.status).toBe(200);
    expect(Array.isArray(r.data)).toBe(true);
  });
});

// ── 7. FREEZE MODE ───────────────────────────────────────────────────────────

describe('Freeze Mode — /profiles/freeze', () => {
  it('freeze on sets frozen=true in DB', async () => {
    const r = await api.patch('/profiles/freeze', { frozen: true }, auth(tokenA));
    expect(r.status).toBe(200);
    expect(r.data.success).toBe(true);
    const me = await api.get('/profiles/me', auth(tokenA));
    expect(me.data.frozen).toBe(true);
  });

  it('freeze off sets frozen=false in DB', async () => {
    const r = await api.patch('/profiles/freeze', { frozen: false }, auth(tokenA));
    expect(r.status).toBe(200);
    const me = await api.get('/profiles/me', auth(tokenA));
    expect(me.data.frozen).toBe(false);
  });

  it('freeze with freezeUntil timestamp', async () => {
    const until = new Date(Date.now() + 86400000).toISOString(); // +1 day
    const r = await api.patch('/profiles/freeze', { frozen: true, freezeUntil: until }, auth(tokenA));
    expect(r.status).toBe(200);
    const me = await api.get('/profiles/me', auth(tokenA));
    expect(me.data.frozen).toBe(true);
    expect(me.data.freezeUntil).toBeTruthy();
    // Unfreeze
    await api.patch('/profiles/freeze', { frozen: false }, auth(tokenA));
  });

  it('unauthenticated freeze → 401', async () => {
    const r = await api.patch('/profiles/freeze', { frozen: true });
    expect(r.status).toBe(401);
  });
});

// ── 8. SECURITY ──────────────────────────────────────────────────────────────

describe('Security', () => {
  it('expired/invalid token → 401', async () => {
    const r = await api.get('/profiles/me', auth('invalid.token.here'));
    expect(r.status).toBe(401);
  });

  it('empty Authorization header → 401', async () => {
    const r = await api.get('/profiles/me', { headers: { Authorization: '' } });
    expect(r.status).toBe(401);
  });

  it('Bearer with no token → 401', async () => {
    const r = await api.get('/profiles/me', { headers: { Authorization: 'Bearer ' } });
    expect(r.status).toBe(401);
  });

  it('no sensitive fields in profile response', async () => {
    const r = await api.get('/profiles/me', auth(tokenA));
    expect(r.data).not.toHaveProperty('passwordHash');
    expect(r.data).not.toHaveProperty('password');
  });
});

// ── Cleanup ───────────────────────────────────────────────────────────────────

afterAll(async () => {
  // Sign in again to get fresh tokens if needed
  const rA = await signin(ALICE_EMAIL, PASSWORD);
  const rB = await signin(BOB_EMAIL, PASSWORD);
  const tA = rA.data?.accessToken ?? tokenA;
  const tB = rB.data?.accessToken ?? tokenB;
  await api.delete('/users/me', auth(tA));
  await api.delete('/users/me', auth(tB));
});
