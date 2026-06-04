# Freezme — Production Hardening & Scaling Runbook

Status snapshot (2026-06): single `t3.small` API box behind an ALB, RDS
Postgres `db.t3.micro` Multi-AZ, **local** Redis on the API box. Healthy and
correct for pre-launch / low traffic. This runbook lists the remaining steps to
make it scale, grouped by what they cost and what they need from a human.

---

## ✅ Already in place (verified)
- RDS: 7-day automated backups, **PITR**, **Multi-AZ failover**, encrypted at
  rest, deletion protection. (Data layer is already production-grade.)
- ALB health check on `/health` (30s), deregistration delay 300s.
- PM2 systemd unit (survives reboot) + `pm2 save` dump refreshed.
- `pm2-logrotate` (20 MB cap, 7-day retain, gzip) — logs can't fill disk.
- Worker isolation in code (`RUN_WORKERS` guard) + API/worker PM2 split config.
- CI deploy fixed: correct host, typecheck-gated, prebuilt dist, health-gated.

---

## 🔑 STEP 1 — Re-enable push notifications (needs a SECRET only you have)
**Why:** prod logs show `[FCM] Firebase service account not found — push
disabled`. No match/message pushes today. Biggest user-facing gap.

1. Firebase console → Project Settings → Service Accounts → **Generate new
   private key** (rotate the old exposed one if not already).
2. Copy it to the box, OUTSIDE git, locked down:
   ```bash
   scp -i ~/.ssh/freezme-cli-key.pem firebase-service-account.json \
     ubuntu@51.20.252.164:~/freezme-server/firebase-service-account.json
   ssh ... 'chmod 600 ~/freezme-server/firebase-service-account.json'
   ```
3. Ensure `.env` has `GOOGLE_APPLICATION_CREDENTIALS=/home/ubuntu/freezme-server/firebase-service-account.json`
   (or whatever path `src/services/fcm.ts` reads).
4. `pm2 reload freezme-api --update-env` → confirm logs no longer show the FCM
   warning, send a test push.
- **Cost:** $0.  **Risk:** low.  **Confirm `*service-account*.json` is gitignored.**

---

## 💵 STEP 2 — Move Redis to ElastiCache (prerequisite for >1 box)
**Why:** Redis is local to the API box → single point of failure, and BullMQ +
the Socket.IO adapter can't be shared across instances while it's local. This is
the gate that unlocks horizontal scale.

1. Create ElastiCache for Redis (single node `cache.t4g.micro` to start,
   same VPC/subnet/SG as EC2, allow 6379 from the EC2 SG).
2. Set `REDIS_URL=redis://<elasticache-endpoint>:6379` in `.env`.
3. `pm2 reload all --update-env`; verify `[Redis] connected` and BullMQ jobs run.
4. Decommission local `redis-server` once confirmed.
- **Cost:** ~$12–15/mo.  **Risk:** medium (touches sessions/queues — do off-peak).

---

## 💵 STEP 3 — Second API instance + Socket.IO stickiness
**Why:** removes the single-box SPOF that caused the 6-hour outage.
**Hard prerequisites:** Step 2 done (shared Redis), and EITHER keep
`transports: ['websocket']` in prod (already the case) OR enable target-group
stickiness — otherwise Socket.IO handshakes break across instances.

1. AMI/launch-template from the current box (or user-data that pulls + builds).
2. Add instance to target group `freezme-tg`; confirm both show `healthy`.
3. Run the **worker on exactly ONE** box: `DISABLE_WORKERS=true` on the API-only
   instance(s); the dedicated `freezme-worker` runs on one. (ecosystem split
   already supports this.)
4. Optionally bump ALB `idle_timeout` 60→300s for chat sockets.
- **Cost:** +~$15–30/mo per instance.  **Risk:** medium.

---

## 💵 STEP 4 — CloudFront in front of S3 (global image speed)
**Why:** photos served direct from S3 in eu-north-1 → slow for APAC/US users.
Biggest *perceived* speed win for a photo-heavy app.

1. CloudFront distribution, origin = the S3 bucket (OAC, keep bucket private).
2. Point `S3_PUBLIC_BASE_URL` at the CloudFront domain; invalidate on deploy.
3. Long cache TTL on `/uploads/*` (immutable UUID keys).
- **Cost:** ~$1–10/mo at low traffic (then usage-based).  **Risk:** low.

---

## 💵 STEP 5 — RDS read replica (when reads dominate)
**Why:** daily-pool / feed / chat-list are read-heavy; offload from primary.
Only worth it once you see read CPU pressure on the primary (check RDS
Performance Insights first).

1. Create a read replica; add a second read-only Prisma client.
2. Route GET-only hot paths to the replica; keep writes on primary.
- **Cost:** ~ another micro/small instance.  **Risk:** medium (replica lag on
  read-after-write — keep just-written reads on primary).

---

## 🛠 Also worth doing (cheap, not yet done)
- **Geohash bbox pre-filter on daily-pool** (`profiles.ts`): currently scans by
  presenceScore then JS-distance-filters; fixes sparse-area empty pools + speed.
- **APM**: enable RDS Performance Insights + `pg_stat_statements`; add p50/p99
  latency dashboards (the app has Sentry for errors but no perf metrics).
- **PgBouncer** once you run >1 box (Prisma `connection_limit=10`/worker can
  exhaust RDS connections).
- **i18n**: wire `AppLocalizations` through screens or drop the dead .arb files.
- **Pool timezone**: pool open/close hardcoded to IST — make per-user or declare
  "India-first" for global launch.

## Ordering
Step 1 (push) → Step 4 (CDN) are low-risk wins do-anytime. Steps 2→3 are the
real scale unlock and must be done in order. Step 5 only when metrics justify.
