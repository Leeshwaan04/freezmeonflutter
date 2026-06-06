/**
 * purge-test-accounts.ts — Find (and optionally soft-delete) test / probe accounts
 * that pollute the production matching pool.
 *
 * SAFE BY DEFAULT: runs as a DRY RUN and only prints what it would do.
 * Nothing is modified unless you pass --apply.
 *
 *   Dry run (default — review the list):
 *     cd server && npx ts-node scripts/purge-test-accounts.ts
 *
 *   Apply (soft-delete the AUTO tier only):
 *     cd server && npx ts-node scripts/purge-test-accounts.ts --apply
 *
 *   Also soft-delete the REVIEW tier (personal-looking test names):
 *     cd server && npx ts-node scripts/purge-test-accounts.ts --apply --include-review
 *
 * Soft-delete mirrors DELETE /users/me: sets user.status='deleted', clears FCM,
 * removes presence/queue/likes/feed and deactivates matches. The GDPR purge cron
 * hard-deletes after the grace window. The daily-pool already excludes
 * status!='active', so these vanish from discovery immediately.
 */
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const APPLY = process.argv.includes('--apply');
const INCLUDE_REVIEW = process.argv.includes('--include-review');

// ── Classifiers ──────────────────────────────────────────────────────────────
// AUTO: high-confidence test/probe — safe to remove automatically.
const TEST_EMAIL_DOMAINS = ['@freezmetest.com', '@example.com', '@test.com'];
// Injection / script / control payloads in a display name → not a real person.
const INJECTION_RE = /['"`;<>]|--|\bunion\s+select\b|\bor\b\s+\d+\s*=\s*\d+|<\s*script/i;
// Obvious QA/E2E naming.
const AUTO_NAME_RE = /\b(qa|e2e|test\s*user|test\s*account|automation|smoke\s*test)\b/i;

// REVIEW: likely test but personal-looking — only removed with --include-review.
const REVIEW_NAME_RE = /\b(test|demo|dummy|sample|asdf|qwerty)\b/i;

type Tier = 'AUTO' | 'REVIEW';
interface Candidate { uid: string; name: string | null; email: string | null; createdAt: Date; tier: Tier; reason: string; }

function classify(u: { id: string; email: string | null; status: string; createdAt: Date; profile: { name: string | null } | null }): Candidate | null {
  if (u.status !== 'active') return null; // already gone
  const name = u.profile?.name ?? null;
  const email = u.email ?? null;
  const lcEmail = (email ?? '').toLowerCase();

  if (TEST_EMAIL_DOMAINS.some(d => lcEmail.endsWith(d)))
    return { uid: u.id, name, email, createdAt: u.createdAt, tier: 'AUTO', reason: `test email domain` };
  if (name && INJECTION_RE.test(name))
    return { uid: u.id, name, email, createdAt: u.createdAt, tier: 'AUTO', reason: `injection/probe payload in name` };
  if (name && AUTO_NAME_RE.test(name))
    return { uid: u.id, name, email, createdAt: u.createdAt, tier: 'AUTO', reason: `QA/E2E name pattern` };
  if (name && REVIEW_NAME_RE.test(name))
    return { uid: u.id, name, email, createdAt: u.createdAt, tier: 'REVIEW', reason: `generic test-ish name (review)` };
  return null;
}

async function softDelete(uid: string) {
  await prisma.$transaction(async (tx) => {
    await tx.user.update({ where: { id: uid }, data: { status: 'deleted', fcmToken: null } });
    await tx.refreshToken.deleteMany({ where: { userId: uid } });
    await tx.blindsQueue.deleteMany({ where: { uid } });
    await tx.pathsPresence.deleteMany({ where: { uid } });
    await tx.feedPost.deleteMany({ where: { authorUid: uid } });
    await tx.like.deleteMany({ where: { senderUid: uid } });
    const matches = await tx.match.findMany({ where: { members: { has: uid } } });
    for (const m of matches) await tx.match.update({ where: { id: m.id }, data: { status: 'inactive' } });
  });
}

async function main() {
  const users = await prisma.user.findMany({
    select: { id: true, email: true, status: true, createdAt: true, profile: { select: { name: true } } },
  });
  const candidates = users.map(classify).filter((c): c is Candidate => c !== null);
  const auto = candidates.filter(c => c.tier === 'AUTO');
  const review = candidates.filter(c => c.tier === 'REVIEW');

  const fmt = (c: Candidate) =>
    `  [${c.tier}] ${(c.name ?? '(no name)').padEnd(28)} ${(c.email ?? '').padEnd(34)} ${c.createdAt.toISOString().slice(0, 10)}  — ${c.reason}`;

  console.log(`\n=== Test/probe account scan (${users.length} active users scanned) ===\n`);
  console.log(`AUTO tier (high-confidence test/probe): ${auto.length}`);
  auto.forEach(c => console.log(fmt(c)));
  console.log(`\nREVIEW tier (personal-looking, needs --include-review): ${review.length}`);
  review.forEach(c => console.log(fmt(c)));

  const toDelete = INCLUDE_REVIEW ? [...auto, ...review] : auto;

  if (!APPLY) {
    console.log(`\nDRY RUN — nothing changed. Would soft-delete ${toDelete.length} account(s).`);
    console.log(`Re-run with --apply to execute${INCLUDE_REVIEW ? '' : ' (add --include-review to also remove the REVIEW tier)'}.\n`);
    return;
  }

  console.log(`\n--apply set → soft-deleting ${toDelete.length} account(s)...`);
  let done = 0;
  for (const c of toDelete) {
    try { await softDelete(c.uid); done++; console.log(`  ✓ ${c.name ?? c.uid}`); }
    catch (e) { console.error(`  ✗ ${c.name ?? c.uid}: ${(e as Error).message}`); }
  }
  console.log(`\nDone. Soft-deleted ${done}/${toDelete.length}. They are excluded from the pool immediately; the GDPR cron will hard-purge after the grace window.\n`);
}

main().catch((e) => { console.error(e); process.exit(1); }).finally(() => prisma.$disconnect());
