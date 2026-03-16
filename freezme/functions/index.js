/* eslint-disable max-len */
"use strict";

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ─── Rate-limit helper ────────────────────────────────────────────────────────
// Stores counters in Firestore under _rateLimits/{uid}/actions/{action}.
// Returns true if the call is allowed, false if the limit is exceeded.
async function checkRateLimit(uid, action, maxCalls, windowSeconds) {
  const ref = db.doc(`_rateLimits/${uid}/actions/${action}`);
  const now = Date.now();
  const windowStart = now - windowSeconds * 1000;

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.exists ? snap.data() : { calls: [] };

    // Drop calls outside the window
    const recent = (data.calls || []).filter((ts) => ts > windowStart);

    if (recent.length >= maxCalls) {
      return false; // rate limited
    }

    recent.push(now);
    tx.set(ref, { calls: recent });
    return true;
  });
}

// ─── deleteAccount ─────────────────────────────────────────────────────────────
// Full GDPR wipe: deletes all user data across every Firestore collection
// then deletes the Firebase Auth account.
exports.deleteAccount = onCall({ enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in to delete account.");
  }

  const batch = db.batch();

  // Collections that store per-user documents directly keyed by UID
  const ownedCollections = [
    "users",
    "profiles",
    "onboarding",
    "preferences",
    "notifications",
    "rateLimitCounters",
  ];
  for (const col of ownedCollections) {
    batch.delete(db.doc(`${col}/${uid}`));
  }

  // Sub-collections under the user document
  const userSubcollections = ["messages", "matches", "vibeCredits", "sessions"];
  for (const sub of userSubcollections) {
    const snaps = await db.collection(`users/${uid}/${sub}`).get();
    snaps.forEach((doc) => batch.delete(doc.ref));
  }

  // Messages sent by this user in any conversation
  const sentMessages = await db
    .collectionGroup("messages")
    .where("senderId", "==", uid)
    .get();
  sentMessages.forEach((doc) => batch.delete(doc.ref));

  // Feed posts authored by this user
  const posts = await db.collection("feed").where("authorId", "==", uid).get();
  posts.forEach((doc) => batch.delete(doc.ref));

  // Likes left by this user
  const likes = await db.collection("likes").where("userId", "==", uid).get();
  likes.forEach((doc) => batch.delete(doc.ref));

  // Paths (location invites) created by or targeting this user
  const pathsCreated = await db.collection("paths").where("creatorId", "==", uid).get();
  pathsCreated.forEach((doc) => batch.delete(doc.ref));
  const pathsReceived = await db.collection("paths").where("targetId", "==", uid).get();
  pathsReceived.forEach((doc) => batch.delete(doc.ref));

  // Rate-limit counters for this user
  const rateRef = db.collection(`_rateLimits/${uid}/actions`);
  const rateDocs = await rateRef.get();
  rateDocs.forEach((doc) => batch.delete(doc.ref));
  batch.delete(db.doc(`_rateLimits/${uid}`));

  await batch.commit();

  // Delete Firebase Storage objects (profile photos, posts)
  try {
    const bucket = admin.storage().bucket();
    await bucket.deleteFiles({ prefix: `users/${uid}/` });
  } catch (_) {
    // Non-fatal: storage cleanup best-effort
  }

  // Delete the Firebase Auth account last
  await admin.auth().deleteUser(uid);

  return { success: true };
});

// ─── sendInvite ────────────────────────────────────────────────────────────────
// Rate-limited: max 20 invites per hour per user.
exports.sendInvite = onCall({ enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const allowed = await checkRateLimit(uid, "sendInvite", 20, 3600);
  if (!allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Too many invites. Please wait before sending more."
    );
  }

  const { targetUid, message } = request.data;
  if (!targetUid || typeof targetUid !== "string") {
    throw new HttpsError("invalid-argument", "targetUid is required.");
  }

  await db.collection("invites").add({
    fromUid: uid,
    toUid: targetUid,
    message: message || "",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "pending",
  });

  return { success: true };
});

// ─── sendMessage ───────────────────────────────────────────────────────────────
// Rate-limited: max 60 messages per minute per user.
exports.sendMessage = onCall({ enforceAppCheck: false }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const allowed = await checkRateLimit(uid, "sendMessage", 60, 60);
  if (!allowed) {
    throw new HttpsError(
      "resource-exhausted",
      "Sending too fast. Please slow down."
    );
  }

  const { conversationId, text } = request.data;
  if (!conversationId || !text) {
    throw new HttpsError("invalid-argument", "conversationId and text are required.");
  }

  await db
    .collection("conversations")
    .doc(conversationId)
    .collection("messages")
    .add({
      senderId: uid,
      text,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });

  // Update conversation lastMessage
  await db.collection("conversations").doc(conversationId).set(
    {
      lastMessage: text,
      lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSenderId: uid,
    },
    { merge: true }
  );

  return { success: true };
});

// ─── onNewMatch trigger ────────────────────────────────────────────────────────
// Sends a push notification when a new match document is written.
exports.onNewMatch = onDocumentCreated("matches/{matchId}", async (event) => {
  const match = event.data?.data();
  if (!match) return;

  const { userAId, userBId } = match;

  const [snapA, snapB] = await Promise.all([
    db.doc(`users/${userAId}`).get(),
    db.doc(`users/${userBId}`).get(),
  ]);

  const userA = snapA.data();
  const userB = snapB.data();

  const sendNotif = async (toUid, fromName) => {
    const tokenSnap = await db.doc(`users/${toUid}`).get();
    const fcmToken = tokenSnap.data()?.fcmToken;
    if (!fcmToken) return;
    await admin.messaging().send({
      token: fcmToken,
      notification: {
        title: "New Match! 💜",
        body: `You matched with ${fromName}`,
      },
      data: { type: "match" },
    });
  };

  await Promise.allSettled([
    sendNotif(userAId, userB?.displayName || "someone"),
    sendNotif(userBId, userA?.displayName || "someone"),
  ]);
});

// ─── Helper: send FCM to a single user ────────────────────────────────────────
async function sendFcm(uid, title, body, data = {}) {
  const snap = await db.doc(`users/${uid}`).get();
  const token = snap.data()?.fcmToken;
  if (!token) return;
  await admin.messaging().send({ token, notification: { title, body }, data });
}

// ─── expireMatches ─────────────────────────────────────────────────────────────
// Runs every hour. Marks unstarted matches as 'expired' when their timer runs
// out, and notifies both users.
exports.expireMatches = onSchedule("every 60 minutes", async () => {
  const now = admin.firestore.Timestamp.now();

  const snap = await db.collection("matches")
    .where("expiresAt", "<=", now)
    .where("hasConversationStarted", "==", false)
    .where("status", "!=", "expired")
    .limit(200)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  const notifs = [];

  for (const doc of snap.docs) {
    const m = doc.data();
    batch.update(doc.ref, {
      status: "expired",
      expiredAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const nameA = m.userAName || "your match";
    const nameB = m.userBName || "your match";
    notifs.push(sendFcm(m.userAId, "Match melted ❄️", `Your connection with ${nameB} has melted.`, { type: "match_expired", matchId: doc.id }));
    notifs.push(sendFcm(m.userBId, "Match melted ❄️", `Your connection with ${nameA} has melted.`, { type: "match_expired", matchId: doc.id }));
  }

  await batch.commit();
  await Promise.allSettled(notifs);
});

// ─── meltWarnings ──────────────────────────────────────────────────────────────
// Runs every hour. Sends a "6 hours left" push notification once per match,
// so users are nudged to start the conversation before it melts.
exports.meltWarnings = onSchedule("every 60 minutes", async () => {
  const now = Date.now();
  // Window: matches expiring between 6h and 7h from now
  const sixH = admin.firestore.Timestamp.fromDate(new Date(now + 6 * 3600 * 1000));
  const sevenH = admin.firestore.Timestamp.fromDate(new Date(now + 7 * 3600 * 1000));

  const snap = await db.collection("matches")
    .where("expiresAt", ">=", sixH)
    .where("expiresAt", "<=", sevenH)
    .where("hasConversationStarted", "==", false)
    .where("meltWarningSent", "!=", true)
    .limit(200)
    .get();

  if (snap.empty) return;

  const batch = db.batch();
  const notifs = [];

  for (const doc of snap.docs) {
    const m = doc.data();
    batch.update(doc.ref, { meltWarningSent: true });
    const nameA = m.userAName || "your match";
    const nameB = m.userBName || "your match";
    notifs.push(sendFcm(m.userAId, `🔥 ${nameB} melts in 6h`, "Send a message before the connection disappears!", { type: "melt_warning", matchId: doc.id }));
    notifs.push(sendFcm(m.userBId, `🔥 ${nameA} melts in 6h`, "Send a message before the connection disappears!", { type: "melt_warning", matchId: doc.id }));
  }

  await batch.commit();
  await Promise.allSettled(notifs);
});
