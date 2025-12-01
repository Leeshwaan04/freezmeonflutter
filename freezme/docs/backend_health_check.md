Backend Health Check – Freezme
==============================

Use this quick list to validate backend readiness for Paths/Blinds/Auth/Chat.

Environment sanity
- Verify Firebase project/app: `freezme-844cc`, package `com.freezme.app`, correct `google-services.json` + `GoogleService-Info.plist` in the app.
- SHA keys in Firebase match your signing keystore (Google Sign-In).
- Firestore rules enforce auth; no public writes.

Functions / Emulators
- From `backend/functions`: `npm install` (once), then `npm test` or `firebase emulators:exec --project freezme-844cc 'npm test'`.
- Check Cloud Functions logs for recent errors after deploy.

Auth flow
- Test Google/Apple/Email: one success + one forced failure; ensure buttons disable while loading and errors surface.
- Sign-out: presence/offline update, session teardown, `FirebaseAuth.signOut()` succeeds.

Paths (Near)
- Data model: `paths_presence` (uid, intents, coarse geohash/lat/lng, visible_until, radius_km, last_active_at, availability, interests summary).
- Invites: `path_invites` (sender_uid, receiver_uid, intent, status=pending/accepted/declined/expired, created_at, responded_at).
- Enforce wave/invite daily limits; reject when exceeded.
- Queries: geohash within radius + intent filter; exclude blocked; return coarse distance only.
- Notifications: push on invite; push on accept/decline.

Blinds (Anonymous chat)
- Queue: `blinds_queue` (uid, intent, distance bucket, interests tags, available_until, last_active).
- Sessions: `blinds_sessions` (phase=anonymous/reveal, expires_at, reveal flags, report status).
- Auto-expire sessions; remove from queue on match/expiry/block.
- Reports/blocks: remove from queue and prevent rematch; respect blocklist globally.

Chat/messaging
- Message status writes (sent/delivered/read) propagate to UI; check listener/logs.
- Typing/presence optional; avoid leaking precise location/PII.
- Content moderation/retention: apply policy if storing transcripts.

Safety / Rate limits
- Global blocklist enforced across Paths/Blinds/Feed/Chat queries.
- Rate limit invites/waves and blind roll attempts.
- Contact-sharing prevention in Blinds if you allow media/text storage.

Monitoring
- Watch Cloud Function error rate and Firestore/RTDB quota.
- Analytics events for: sign-in failures, invite send/accept/decline, blind session start/end, reports/blocks.

Release checklist
- `flutter test` (if present), `flutter analyze`.
- `npm test` in `backend/functions` (if applicable).
- `firebase deploy --only functions` only after green checks and correct configs.
