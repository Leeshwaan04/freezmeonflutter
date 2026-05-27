import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { geohashForCoords } from '../services/geo';
import { sanitizeText } from '../utils/validate';
import { logger } from '../services/logger';

const router = Router();
router.use(requireAuth);

// ─────────────────────────────────────────────────────────────────────────────
// FREEZME MATCHING ENGINE v2
//
// Scoring budget: 200 points
//
// Layer 1 — Hard filters (applied in DB query, eliminates non-starters):
//   • gender preference enforcement (mutual)
//   • age range enforcement (mutual)
//   • distance cap enforcement
//   • not frozen, not self, not already liked/skipped
//   • intent hard-block: friendship-only users are pooled separately
//
// Layer 2 — Soft scores (computed per candidate, total = 200 pts):
//   Mutual pending like     50 pts  — they already swiped right on you
//   Intent alignment        25 pts  — what you're both here for
//   Energy compatibility    20 pts  — deepDiver/roomIgniter/quietStorm/openRoad
//   Personality traits      20 pts  — complementary pairings (research-backed matrix)
//   Pace alignment          15 pts  — how fast each moves emotionally
//   Shared interests        15 pts  — overlap of interest tags
//   Lifestyle overlap       10 pts  — fitness/travel/career/creative/spiritual
//   Presence window overlap 10 pts  — when you're actually both available
//   Geo proximity           10 pts  — closer = higher (within distanceKm cap)
//   Recency                  5 pts  — recently active users score higher
//
// Cross-gender design principle:
//   Female users see male candidates that match their genderPrefs.
//   Male users see female candidates that match their genderPrefs.
//   The algorithm is gender-neutral in scoring but gender-strict in filtering —
//   we only surface candidates where BOTH sides' genderPrefs are compatible.
//   This prevents wasted impressions and respects stated preferences absolutely.
// ─────────────────────────────────────────────────────────────────────────────

// ── Personality trait compatibility matrix ───────────────────────────────────
// Complementary pairings score higher (introvert↔extrovert = 1.0)
// Identical introverts score 0.6 — comfort but less growth tension
const TRAIT_COMPAT: Record<string, Record<string, number>> = {
  introvert:   { introvert: 0.6, extrovert: 1.0, adventurous: 0.7, cautious: 0.8, logical: 0.7, emotional: 0.8, spontaneous: 0.6, planner: 0.9 },
  extrovert:   { introvert: 1.0, extrovert: 0.7, adventurous: 0.9, cautious: 0.6, logical: 0.6, emotional: 0.8, spontaneous: 0.9, planner: 0.6 },
  adventurous: { introvert: 0.7, extrovert: 0.9, adventurous: 1.0, cautious: 0.8, logical: 0.6, emotional: 0.7, spontaneous: 1.0, planner: 0.6 },
  cautious:    { introvert: 0.8, extrovert: 0.6, adventurous: 0.8, cautious: 0.6, logical: 0.9, emotional: 0.7, spontaneous: 0.6, planner: 1.0 },
  logical:     { introvert: 0.7, extrovert: 0.6, adventurous: 0.6, cautious: 0.9, logical: 0.7, emotional: 1.0, spontaneous: 0.6, planner: 0.8 },
  emotional:   { introvert: 0.8, extrovert: 0.8, adventurous: 0.7, cautious: 0.7, logical: 1.0, emotional: 0.7, spontaneous: 0.8, planner: 0.7 },
  spontaneous: { introvert: 0.6, extrovert: 0.9, adventurous: 1.0, cautious: 0.6, logical: 0.6, emotional: 0.8, spontaneous: 0.7, planner: 0.9 },
  planner:     { introvert: 0.9, extrovert: 0.6, adventurous: 0.6, cautious: 1.0, logical: 0.8, emotional: 0.7, spontaneous: 0.9, planner: 0.6 },
};

// ── Energy type compatibility matrix ─────────────────────────────────────────
// deepDiver: deep 1-on-1 conversations, slow burn
// roomIgniter: social, high energy, loves crowds
// quietStorm: introverted but intense when connected
// openRoad: spontaneous, adaptable, goes with flow
//
// Cross-gender research insight: deepDiver woman + quietStorm man = highest
// reported satisfaction (depth-seeking alignment). roomIgniter pairs = fun
// but lower long-term compatibility. openRoad = wildcard, adapts to most.
const ENERGY_COMPAT: Record<string, Record<string, number>> = {
  deepDiver:    { deepDiver: 1.0, roomIgniter: 0.5, quietStorm: 0.95, openRoad: 0.7 },
  roomIgniter:  { deepDiver: 0.5, roomIgniter: 0.8, quietStorm: 0.55, openRoad: 0.9 },
  quietStorm:   { deepDiver: 0.95, roomIgniter: 0.55, quietStorm: 0.75, openRoad: 0.8 },
  openRoad:     { deepDiver: 0.7, roomIgniter: 0.9, quietStorm: 0.8, openRoad: 0.85 },
};

// ── Pace alignment matrix ────────────────────────────────────────────────────
// Same pace = high compatibility. Extreme mismatch (quickConnector + takesTheirTime)
// is the #1 early drop-off reason in dating apps.
const PACE_COMPAT: Record<string, Record<string, number>> = {
  takesTheirTime:     { takesTheirTime: 1.0, movesWithInterest: 0.75, quickConnector: 0.2 },
  movesWithInterest:  { takesTheirTime: 0.75, movesWithInterest: 1.0, quickConnector: 0.75 },
  quickConnector:     { takesTheirTime: 0.2, movesWithInterest: 0.75, quickConnector: 1.0 },
};

// ── Scoring functions ─────────────────────────────────────────────────────────

function traitCompatScore(myTraits: string[], theirTraits: string[]): number {
  if (!myTraits.length || !theirTraits.length) return 0.5;
  let total = 0, count = 0;
  for (const mine of myTraits) {
    for (const theirs of theirTraits) {
      total += TRAIT_COMPAT[mine]?.[theirs] ?? 0.5;
      count++;
    }
  }
  return count > 0 ? total / count : 0.5;
}

function energyCompatScore(mine: string | null, theirs: string | null): number {
  if (!mine || !theirs) return 0.6; // neutral fallback
  return ENERGY_COMPAT[mine]?.[theirs] ?? 0.6;
}

function paceCompatScore(mine: string | null, theirs: string | null): number {
  if (!mine || !theirs) return 0.6;
  return PACE_COMPAT[mine]?.[theirs] ?? 0.6;
}

function interestOverlap(a: string[], b: string[]): number {
  if (!a.length || !b.length) return 0;
  const setA = new Set(a.map(s => s.toLowerCase()));
  const overlap = b.filter(s => setA.has(s.toLowerCase())).length;
  return overlap / Math.min(a.length, b.length);
}

function lifestyleOverlap(a: string[], b: string[]): number {
  if (!a.length || !b.length) return 0;
  const setA = new Set(a);
  const overlap = b.filter(s => setA.has(s)).length;
  return overlap / Math.min(a.length, b.length);
}

function intentScore(mine: string | null, theirs: string | null): number {
  if (!mine || !theirs) return 0.5;
  if (mine === theirs) return 1.0;
  if ((mine === 'exploring' && theirs === 'meaningful') ||
      (mine === 'meaningful' && theirs === 'exploring')) return 0.7;
  return 0.15; // friendship vs meaningful/exploring = strong mismatch
}

function recencyScore(updatedAt: Date): number {
  const hoursAgo = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60);
  if (hoursAgo < 24)  return 1.0;
  if (hoursAgo < 48)  return 0.8;
  if (hoursAgo < 168) return 0.5;
  if (hoursAgo < 720) return 0.2; // 30 days
  return 0.05; // stale profile — almost no boost
}

// Presence window overlap: what fraction of their availability overlaps with mine
// presenceWindows = [{ day: 0-6, startHour: 6, endHour: 12 }]
function presenceOverlapScore(
  mine: any[] | null,
  theirs: any[] | null,
): number {
  if (!mine?.length || !theirs?.length) return 0.5; // neutral if no data
  // Build slot sets: "day:startHour" strings
  const mySlots = new Set(mine.map((w: any) => `${w.day}:${w.startHour}`));
  const overlap = theirs.filter((w: any) => mySlots.has(`${w.day}:${w.startHour}`)).length;
  const maxSlots = Math.max(mine.length, theirs.length);
  return maxSlots > 0 ? overlap / maxSlots : 0.5;
}

// Haversine distance in km between two lat/lng points
function haversineKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// Geo proximity score: 1.0 at 0km, 0.0 at distanceKm cap
function geoScore(myLat: number | null, myLng: number | null,
                  theirLat: number | null, theirLng: number | null,
                  capKm: number): number {
  if (!myLat || !myLng || !theirLat || !theirLng) return 0.5;
  const dist = haversineKm(myLat, myLng, theirLat, theirLng);
  if (dist > capKm) return 0; // beyond cap — should have been filtered
  return Math.max(0, 1 - dist / capKm);
}

// Normalize gender string to canonical form for comparison
function normalizeGender(g: string | null | undefined): string {
  if (!g) return '';
  const lower = g.toLowerCase().trim();
  if (lower === 'man' || lower === 'male') return 'man';
  if (lower === 'woman' || lower === 'female') return 'woman';
  if (lower.includes('non') || lower.includes('binary')) return 'nonbinary';
  return lower;
}

// Check if candidate's gender matches viewer's preferences, AND
// viewer's gender matches candidate's preferences (mutual consent)
function mutualGenderMatch(
  myGender: string | null,
  myPrefs: string[],
  theirGender: string | null,
  theirPrefs: string[],
): boolean {
  const myG = normalizeGender(myGender);
  const theirG = normalizeGender(theirGender);

  // I must want their gender
  const iWantThem = myPrefs.length === 0 || myPrefs.some(p => normalizeGender(p) === theirG || theirG === '');
  // They must want my gender
  const theyWantMe = theirPrefs.length === 0 || theirPrefs.some(p => normalizeGender(p) === myG || myG === '');

  return iWantThem && theyWantMe;
}

// GET /profiles/me — fetch own profile (used by IAP and post-login refresh)
router.get('/me', async (req: Request, res: Response) => {
  try {
    const profile = await prisma.profile.findUnique({ where: { userId: req.uid } });
    if (!profile) { res.status(404).json({ code: 'NOT_FOUND', error: 'Profile not found' }); return; }
    const membership = await prisma.membership.findUnique({ where: { userId: req.uid } });
    res.json({ ...profile, isPremium: profile.isPremium || (membership?.active ?? false) });
  } catch (err) {
    res.status(500).json({ code: 'INTERNAL_ERROR', error: 'Failed to fetch profile' });
  }
});

// POST /profiles — create or update profile
router.post('/', async (req: Request, res: Response) => {
  try {
    const {
      name, age, bio, imageUrl, interests,
      intent, personalityTraits, lifestyleFactors, archetype, promptAnswer,
      energyType, paceSignal, presenceWindows,
      gender, genderPrefs, ageMin, ageMax, messagingPref,
      lat, lng,
    } = req.body;

    // Sanitize user-supplied text fields to strip HTML/XSS before storing
    const safeName = typeof name === 'string' ? sanitizeText(name).trim() : name;
    const safeBio = typeof bio === 'string' ? sanitizeText(bio) : bio;

    if (!safeName || typeof safeName !== 'string' || safeName.trim().length < 1 || safeName.length > 60) {
      res.status(400).json({ error: 'name must be 1–60 characters' }); return;
    }
    if (!age || typeof age !== 'number' || age < 18 || age > 100) {
      res.status(400).json({ error: 'age must be between 18 and 100' }); return;
    }
    if (safeBio && (typeof safeBio !== 'string' || safeBio.length > 500)) {
      res.status(400).json({ error: 'bio must be under 500 characters' }); return;
    }
    if (imageUrl !== undefined && imageUrl !== null) {
      try { new URL(imageUrl); } catch {
        res.status(400).json({ error: 'imageUrl must be a valid URL' }); return;
      }
    }

    const VALID_INTENTS = ['meaningful', 'exploring', 'friendship'];
    // Accept both camelCase (Flutter) and snake_case
    const VALID_ENERGY_TYPES = ['deep_diver', 'room_igniter', 'quiet_storm', 'open_road', 'deepDiver', 'roomIgniter', 'quietStorm', 'openRoad'];
    const VALID_PACE_SIGNALS = ['takes_their_time', 'moves_with_interest', 'quick_connector', 'takesTheirTime', 'movesWithInterest', 'quickConnector'];
    const VALID_ARCHETYPES = ['explorer', 'nurturer', 'visionary', 'harmonizer', 'dynamo'];
    // Normalize gender casing: 'Man' → 'man', 'Non-binary' → 'nonbinary'
    const normalizeGenderValue = (g: string) => {
      const lower = g.toLowerCase().replace(/[^a-z]/g, '');
      if (lower === 'nonbinary' || lower === 'nonbinarytransgender') return 'nonbinary';
      if (lower === 'man' || lower === 'male') return 'man';
      if (lower === 'woman' || lower === 'female') return 'woman';
      return lower;
    };
    const normalizedGender = gender !== undefined ? normalizeGenderValue(gender) : undefined;

    const VALID_GENDERS = ['man', 'woman', 'nonbinary', 'other'];
    const VALID_GENDER_PREFS = ['man', 'woman', 'nonbinary'];
    const VALID_MESSAGING_PREFS = ['anyone', 'matches_only'];

    if (normalizedGender !== undefined && !VALID_GENDERS.includes(normalizedGender)) {
      res.status(400).json({ error: `gender must be one of: ${VALID_GENDERS.join(', ')}` }); return;
    }

    if (intent !== undefined && !VALID_INTENTS.includes(intent)) {
      res.status(400).json({ error: `intent must be one of: ${VALID_INTENTS.join(', ')}` }); return;
    }
    // Silently ignore unknown energyType/paceSignal/archetype rather than 400
    const safeEnergyType = energyType !== undefined && VALID_ENERGY_TYPES.includes(energyType) ? energyType : undefined;
    const safePaceSignal = paceSignal !== undefined && VALID_PACE_SIGNALS.includes(paceSignal) ? paceSignal : undefined;
    const safeArchetype = archetype !== undefined && VALID_ARCHETYPES.includes(archetype) ? archetype : undefined;

    // Normalize and filter genderPrefs — strip invalid values rather than rejecting
    const normalizedGenderPrefs = genderPrefs !== undefined && Array.isArray(genderPrefs)
      ? genderPrefs.map(normalizeGenderValue).filter((g: string) => VALID_GENDER_PREFS.includes(g))
      : genderPrefs;

    if (messagingPref !== undefined && !VALID_MESSAGING_PREFS.includes(messagingPref)) {
      res.status(400).json({ error: `messagingPref must be one of: ${VALID_MESSAGING_PREFS.join(', ')}` }); return;
    }
    if (interests !== undefined && (!Array.isArray(interests) || interests.length > 30)) {
      res.status(400).json({ error: 'interests must be an array of at most 30 items' }); return;
    }
    if (personalityTraits !== undefined && (!Array.isArray(personalityTraits) || personalityTraits.length > 8)) {
      res.status(400).json({ error: 'personalityTraits must be an array of at most 8 items' }); return;
    }
    if (lifestyleFactors !== undefined && (!Array.isArray(lifestyleFactors) || lifestyleFactors.length > 8)) {
      res.status(400).json({ error: 'lifestyleFactors must be an array of at most 8 items' }); return;
    }
    if (promptAnswer !== undefined && promptAnswer !== null) {
      if (typeof promptAnswer !== 'object' ||
          typeof promptAnswer.prompt !== 'string' || promptAnswer.prompt.length > 200 ||
          typeof promptAnswer.answer !== 'string' || promptAnswer.answer.length > 500) {
        res.status(400).json({ error: 'promptAnswer must have prompt (≤200 chars) and answer (≤500 chars)' }); return;
      }
    }
    if (ageMin !== undefined && (typeof ageMin !== 'number' || ageMin < 18 || ageMin > 100)) {
      res.status(400).json({ error: 'ageMin must be 18–100' }); return;
    }
    if (ageMax !== undefined && (typeof ageMax !== 'number' || ageMax < 18 || ageMax > 100)) {
      res.status(400).json({ error: 'ageMax must be 18–100' }); return;
    }
    if (ageMin !== undefined && ageMax !== undefined && ageMin > ageMax) {
      res.status(400).json({ error: 'ageMin cannot be greater than ageMax' }); return;
    }

    // Normalize camelCase → snake_case for energyType and paceSignal (Flutter sends camelCase)
    const camelToSnake = (s: string) => s.replace(/([A-Z])/g, '_$1').toLowerCase();
    const normalizedEnergyType = energyType ? camelToSnake(energyType) : energyType;
    const normalizedPaceSignal = paceSignal ? camelToSnake(paceSignal) : paceSignal;

    const profile = await prisma.profile.upsert({
      where: { userId: req.uid },
      update: {
        name: safeName, age, bio: safeBio, imageUrl,
        interests: interests ?? [],
        ...(normalizedGender !== undefined && { gender: normalizedGender }),
        ...(intent !== undefined && { intent }),
        ...(personalityTraits !== undefined && { personalityTraits }),
        ...(lifestyleFactors !== undefined && { lifestyleFactors }),
        ...(safeArchetype !== undefined && { archetype: safeArchetype }),
        ...(promptAnswer !== undefined && { promptAnswer }),
        ...(safeEnergyType !== undefined && { energyType: camelToSnake(safeEnergyType) }),
        ...(safePaceSignal !== undefined && { paceSignal: camelToSnake(safePaceSignal) }),
        ...(presenceWindows !== undefined && { presenceWindows }),
        ...(normalizedGenderPrefs !== undefined && { genderPrefs: normalizedGenderPrefs }),
        ...(ageMin !== undefined && { ageMin }),
        ...(ageMax !== undefined && { ageMax }),
        ...(messagingPref !== undefined && { messagingPref }),
        ...(lat !== undefined && { lat }),
        ...(lng !== undefined && { lng }),
      },
      create: {
        userId: req.uid,
        name: safeName, age, bio: safeBio, imageUrl,
        gender: normalizedGender ?? null,
        interests: interests ?? [],
        intent: intent ?? null,
        personalityTraits: personalityTraits ?? [],
        lifestyleFactors: lifestyleFactors ?? [],
        archetype: safeArchetype ?? null,
        promptAnswer: promptAnswer ?? null,
        energyType: safeEnergyType ? camelToSnake(safeEnergyType) : null,
        paceSignal: safePaceSignal ? camelToSnake(safePaceSignal) : null,
        presenceWindows: presenceWindows ?? null,
        genderPrefs: normalizedGenderPrefs ?? [],
        ageMin: ageMin ?? 18,
        ageMax: ageMax ?? 99,
        messagingPref: messagingPref ?? 'anyone',
        lat: lat ?? null,
        lng: lng ?? null,
      },
    });

    res.json({ ...profile, uid: profile.userId });
  } catch (err) {
    console.error('[profiles POST]', err);
    res.status(500).json({ error: 'Failed to save profile' });
  }
});

// GET /profiles/daily-pool — Freezme Matching Engine v2
router.get('/daily-pool', async (req: Request, res: Response) => {
  try {
    const uid = req.uid;

    const [likes, skips, myProfile] = await Promise.all([
      prisma.like.findMany({ where: { senderUid: uid }, select: { targetUid: true } }),
      prisma.skip.findMany({ where: { senderUid: uid }, select: { targetUid: true } }),
      prisma.profile.findUnique({ where: { userId: uid } }),
    ]);

    if (!myProfile) {
      res.status(404).json({ code: 'NO_PROFILE', error: 'Complete your profile first' });
      return;
    }

    const excluded = new Set([uid, ...likes.map(l => l.targetUid), ...skips.map(s => s.targetUid)]);

    // Who already liked me (excluding already-excluded users)
    const pendingLikesForMe = await prisma.like.findMany({
      where: { targetUid: uid, senderUid: { notIn: Array.from(excluded) } },
      select: { senderUid: true },
    });
    const pendingLikerUids = new Set(pendingLikesForMe.map(l => l.senderUid));

    // ── Build hard-filter WHERE clause ───────────────────────────────────────
    // 1. Gender filter: only fetch candidates whose gender is in MY prefs
    //    We enforce mutuality in JS (can't do bidirectional array check in Prisma easily)
    const myGenderPrefs = myProfile.genderPrefs ?? [];
    const genderFilter = myGenderPrefs.length > 0
      ? { gender: { in: myGenderPrefs } }
      : {};

    // 2. Age filter: candidate's age must be within MY stated range
    const ageFilter = {
      age: { gte: myProfile.ageMin ?? 18, lte: myProfile.ageMax ?? 99 },
    };

    // 3. Intent hard-block: friendship-only users only see other friendship users
    //    Meaningful/exploring users are pooled together
    const intentFilter = myProfile.intent === 'friendship'
      ? { intent: 'friendship' }
      : { intent: { not: 'friendship' } };

    // 4. Distance filter: only fetch profiles that have location data if I do
    //    We post-filter by distance in JS (Prisma can't do haversine)
    const myDistanceCap = myProfile.distanceKm ?? 50;
    const hasMyLocation = myProfile.lat != null && myProfile.lng != null;

    // Fetch candidate pool — 100 to score down to 20 (select only scoring fields, not full profile)
    const candidates = await prisma.profile.findMany({
      where: {
        userId: { notIn: Array.from(excluded) },
        frozen: false,
        ...genderFilter,
        ...ageFilter,
        ...intentFilter,
      },
      select: {
        userId: true,
        name: true,
        age: true,
        bio: true,
        imageUrl: true,
        gender: true,
        genderPrefs: true,
        interests: true,
        personalityTraits: true,
        lifestyleFactors: true,
        energyType: true,
        paceSignal: true,
        archetype: true,
        promptAnswer: true,
        lat: true,
        lng: true,
        presenceScore: true,
        presenceLabel: true,
        presenceWindows: true,
        ageMin: true,
        ageMax: true,
        distanceKm: true,
        intent: true,
        isPremium: true,
        updatedAt: true,
      },
      take: 100,
      orderBy: { presenceScore: 'desc' },
    });

    // ── Score each candidate ─────────────────────────────────────────────────
    const myInterestSet = new Set((myProfile.interests ?? []).map(s => s.toLowerCase()));
    const myWindows = myProfile.presenceWindows as any[] | null;

    const scored = candidates
      .filter(c => {
        // Mutual gender preference check (JS-side, bidirectional)
        const genderOk = mutualGenderMatch(
          myProfile.gender, myProfile.genderPrefs ?? [],
          c.gender, c.genderPrefs ?? [],
        );
        if (!genderOk) return false;

        // Mutual age range check: I must also be in their stated range
        const myAge = myProfile.age;
        const ageOk = myAge >= (c.ageMin ?? 18) && myAge <= (c.ageMax ?? 99);
        if (!ageOk) return false;

        // Distance cap: if both have location, enforce cap
        if (hasMyLocation && c.lat != null && c.lng != null) {
          const dist = haversineKm(myProfile.lat!, myProfile.lng!, c.lat, c.lng);
          if (dist > myDistanceCap) return false;
        }

        return true;
      })
      .map(c => {
        // ── Layer 2: Soft scores (200 pts total) ──────────────────────────
        const mutualPending = pendingLikerUids.has(c.userId) ? 50 : 0;

        const intentPts   = intentScore(myProfile.intent ?? null, c.intent ?? null) * 25;
        const energyPts   = energyCompatScore(myProfile.energyType ?? null, c.energyType ?? null) * 20;
        const traitPts    = traitCompatScore(myProfile.personalityTraits ?? [], c.personalityTraits) * 20;
        const pacePts     = paceCompatScore(myProfile.paceSignal ?? null, c.paceSignal ?? null) * 15;
        const interestPts = interestOverlap(myProfile.interests ?? [], c.interests) * 15;
        const lifestylePts = lifestyleOverlap(myProfile.lifestyleFactors ?? [], c.lifestyleFactors) * 10;
        const presenceWinPts = presenceOverlapScore(myWindows, c.presenceWindows as any[] | null) * 10;
        const geoPts      = geoScore(myProfile.lat ?? null, myProfile.lng ?? null,
                                     c.lat ?? null, c.lng ?? null, myDistanceCap) * 10;
        const recencyPts  = recencyScore(c.updatedAt) * 5;

        const total = mutualPending + intentPts + energyPts + traitPts + pacePts +
                      interestPts + lifestylePts + presenceWinPts + geoPts + recencyPts;

        // Compatibility score shown to user (0-100, excludes mutual-like boost)
        // Weighted across the 5 deepest signals
        const compatibilityScore = Math.round(
          (intentPts / 25 * 0.25 +
           energyPts / 20 * 0.25 +
           traitPts  / 20 * 0.20 +
           pacePts   / 15 * 0.15 +
           interestPts / 15 * 0.15) * 100
        );

        // Shared interests for UI display
        const sharedInterests = c.interests.filter(i => myInterestSet.has(i.toLowerCase()));

        // Compatibility reasons — top 2 signals for "Why you matched" UI
        const reasons: string[] = [];
        if (energyCompatScore(myProfile.energyType ?? null, c.energyType ?? null) >= 0.85)
          reasons.push('Same energy');
        if (paceCompatScore(myProfile.paceSignal ?? null, c.paceSignal ?? null) >= 0.9)
          reasons.push('Same pace');
        if (intentPts / 25 >= 0.9) reasons.push('Same intentions');
        if (sharedInterests.length >= 3) reasons.push(`Both into ${sharedInterests[0]}`);
        if (traitCompatScore(myProfile.personalityTraits ?? [], c.personalityTraits) >= 0.85)
          reasons.push('Complementary personalities');

        return {
          ...c,
          uid: c.userId,
          _score: total,
          sharedInterests,
          compatibilityScore,
          compatibilityReasons: reasons.slice(0, 2),
        };
      });

    // Sort by score, take top 20
    scored.sort((a, b) => b._score - a._score);
    const pool = scored.slice(0, 20).map(({ _score, ...p }) => p);

    res.json(pool);
  } catch (err) {
    console.error('[profiles/daily-pool]', err);
    res.status(500).json({ error: 'Failed to fetch daily pool' });
  }
});

// GET /profiles/:uid — view another user's public profile (no GPS, no preferences)
router.get('/:uid', async (req: Request, res: Response) => {
  try {
    const profile = await prisma.profile.findUnique({ where: { userId: req.params.uid } });
    if (!profile) { res.status(404).json({ error: 'Profile not found' }); return; }
    // Strip private fields before returning to other users
    const { lat, lng, geohash, genderPrefs, ageMin, ageMax, messagingPref,
            distanceKm, presenceWindows, ...publicProfile } = profile;
    res.json({ ...publicProfile, uid: profile.userId });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PATCH /profiles/location
router.patch('/location', async (req: Request, res: Response) => {
  try {
    const { lat, lng } = req.body;
    if (lat == null || lng == null || typeof lat !== 'number' || typeof lng !== 'number' ||
        isNaN(lat) || isNaN(lng) ||
        lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      res.status(400).json({ error: 'valid lat (-90 to 90) and lng (-180 to 180) required' }); return;
    }
    const geohash = geohashForCoords(lat, lng);
    await prisma.profile.update({
      where: { userId: req.uid },
      data: { lat, lng, geohash },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update location' });
  }
});

// PATCH /profiles/freeze
router.patch('/freeze', async (req: Request, res: Response) => {
  try {
    const { frozen, freezeUntil } = req.body;

    let freezeUntilDate: Date | null = null;
    if (freezeUntil) {
      freezeUntilDate = new Date(freezeUntil);
      if (isNaN(freezeUntilDate.getTime())) {
        res.status(400).json({ error: 'Invalid freezeUntil date' }); return;
      }
      const maxFreeze = new Date();
      maxFreeze.setDate(maxFreeze.getDate() + 180);
      if (freezeUntilDate > maxFreeze) {
        res.status(400).json({ error: 'freezeUntil cannot be more than 180 days from now' }); return;
      }
    }

    await prisma.profile.update({
      where: { userId: req.uid },
      data: {
        frozen: frozen ?? false,
        freezeUntil: freezeUntilDate,
        presenceLabel: frozen ? 'frozen' : 'in_the_flow',
      },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update freeze status' });
  }
});

// PATCH /profiles/presence-window — set weekly availability windows
router.patch('/presence-window', async (req: Request, res: Response) => {
  try {
    const { presenceWindows } = req.body;
    if (!Array.isArray(presenceWindows) || presenceWindows.length > 21) {
      res.status(400).json({ error: 'presenceWindows must be an array of at most 21 entries' }); return;
    }
    for (const w of presenceWindows) {
      if (
        typeof w !== 'object' || w === null ||
        typeof w.day !== 'number' || w.day < 0 || w.day > 6 || !Number.isInteger(w.day) ||
        typeof w.startHour !== 'number' || w.startHour < 0 || w.startHour > 23 || !Number.isInteger(w.startHour) ||
        typeof w.endHour !== 'number' || w.endHour < 1 || w.endHour > 24 || !Number.isInteger(w.endHour) ||
        w.endHour <= w.startHour
      ) {
        res.status(400).json({ error: 'Each window must have day (0-6), startHour (0-23), endHour (1-24) with endHour > startHour' }); return;
      }
    }
    await prisma.profile.update({
      where: { userId: req.uid },
      data: { presenceWindows },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: 'Failed to update presence window' });
  }
});

export default router;
