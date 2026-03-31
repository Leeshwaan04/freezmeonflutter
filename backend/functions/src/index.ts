/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onCall, HttpsError, CallableContext} from "firebase-functions/v1/https";
import {onCall as onCallV2, HttpsError as HttpsErrorV2} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as admin from "firebase-admin";
import {google, androidpublisher_v3 as androidPublisherV3} from "googleapis";

setGlobalOptions({maxInstances: 10});

admin.initializeApp();
const db = admin.firestore();

const PROFILE_COLLECTION = "profiles";
const LIKES_COLLECTION = "likes";
const SKIPS_COLLECTION = "skips";
const MATCHES_COLLECTION = "matches";
const MEMBERSHIPS_COLLECTION = "memberships";
const MELT_SESSIONS_COLLECTION = "melt_sessions";
const CHATS_COLLECTION = "chats";
const PATHS_PRESENCE_COLLECTION = "paths_presence";
const PATH_INVITES_COLLECTION = "path_invites";
const BLINDS_QUEUE_COLLECTION = "blinds_queue";
const BLINDS_SESSIONS_COLLECTION = "blinds_sessions";

// ── Secret Manager bindings (v2 functions only) ───────────────────────────
// Provision with: firebase functions:secrets:set PLAY_SERVICE_ACCOUNT
//                 firebase functions:secrets:set PLAY_BILLING_PACKAGE_NAME
//                 firebase functions:secrets:set APPLE_SHARED_SECRET
const secretPlayServiceAccount = defineSecret("PLAY_SERVICE_ACCOUNT");
const secretPlayPackageName = defineSecret("PLAY_BILLING_PACKAGE_NAME");
const secretAppleSharedSecret = defineSecret("APPLE_SHARED_SECRET");


type Nullable<T> = T | null | undefined;

interface ProfileInput {
  name: string;
  age: number;
  bio?: string;
  distance?: string;
  imageUrl?: string;
  compatibility?: number;
  interests?: string[];
}

const sanitizeProfile = (data: unknown): ProfileInput => {
  if (typeof data !== "object" || data === null) {
    throw new HttpsError(
      "invalid-argument",
      "Profile payload must be an object",
    );
  }

  const payload = data as Record<string, unknown>;
  const name = payload.name;
  const age = payload.age;

  if (typeof name !== "string" || name.trim().length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Profile name is required",
    );
  }
  if (typeof age !== "number" || Number.isNaN(age)) {
    throw new HttpsError(
      "invalid-argument",
      "Profile age is required",
    );
  }

  return {
    name: name.trim(),
    age: Math.round(age),
    bio: typeof payload.bio === "string" ? payload.bio : undefined,
    distance: typeof payload.distance === "string" ?
      payload.distance :
      undefined,
    imageUrl: typeof payload.imageUrl === "string" ?
      payload.imageUrl :
      undefined,
    compatibility: typeof payload.compatibility === "number" ?
      payload.compatibility :
      undefined,
    interests: Array.isArray(payload.interests) ?
      payload.interests.filter((item) => typeof item === "string") :
      undefined,
  };
};

const requireAuth = (context: CallableContext): string => {
  if (!context.auth) {
    throw new HttpsError("unauthenticated", "Authentication required");
  }
  return context.auth.uid;
};



export const createProfile = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const profile = sanitizeProfile(data);

  // Hardening: Prevent client from overriding premium status
  const profileRef = db.collection(PROFILE_COLLECTION).doc(uid);
  const existingDoc = await profileRef.get();
  const isCurrentlyPremium = existingDoc.exists ? existingDoc.data()?.isPremium === true : false;

  await profileRef.set(
    {
      ...profile,
      uid,
      isPremium: isCurrentlyPremium, // Retain existing status
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {merge: true},
  );

  return {ok: true};
});

export const getDailyPool = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const requestedLimit: Nullable<number> = data?.limit;
  const limit =
    typeof requestedLimit === "number" &&
    requestedLimit > 0 &&
    requestedLimit <= 50 ?
      Math.round(requestedLimit) :
      20;

  const [skipSnapshot, likeSnapshot] = await Promise.all([
    db.collection(SKIPS_COLLECTION).doc(uid)
      .collection("targets")
      .get(),
    db.collection(LIKES_COLLECTION).doc(uid)
      .collection("targets")
      .get(),
  ]);

  const excluded = new Set<string>([uid]);
  skipSnapshot.forEach((doc) => excluded.add(doc.id));
  likeSnapshot.forEach((doc) => excluded.add(doc.id));

  const snapshot = await db
    .collection(PROFILE_COLLECTION)
    .orderBy("compatibility", "desc")
    .limit(limit * 2)
    .get();

  const profiles = snapshot.docs
    .map((doc) => doc.data())
    .filter((doc) => doc.uid && !excluded.has(doc.uid as string))
    .slice(0, limit);

  return {profiles};
});

export const skipProfile = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const targetUid =
    typeof data?.targetUid === "string" ? data.targetUid : null;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid is required");
  }
  if (targetUid === uid) {
    throw new HttpsError("failed-precondition", "Cannot skip yourself");
  }

  const targetProfile = await db
    .collection(PROFILE_COLLECTION)
    .doc(targetUid)
    .get();
  if (!targetProfile.exists) {
    throw new HttpsError("not-found", "Target profile does not exist");
  }

  await db
    .collection(SKIPS_COLLECTION)
    .doc(uid)
    .collection("targets")
    .doc(targetUid)
    .set({
      skippedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return {ok: true};
});

export const likeProfile = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const targetUid =
    typeof data?.targetUid === "string" ? data.targetUid : null;
  if (!targetUid) {
    throw new HttpsError("invalid-argument", "targetUid is required");
  }
  if (targetUid === uid) {
    throw new HttpsError("failed-precondition", "Cannot like yourself");
  }

  const targetProfile = await db
    .collection(PROFILE_COLLECTION)
    .doc(targetUid)
    .get();
  if (!targetProfile.exists) {
    throw new HttpsError("not-found", "Target profile does not exist");
  }

  const likeRef = db
    .collection(LIKES_COLLECTION)
    .doc(uid)
    .collection("targets")
    .doc(targetUid);
  const reciprocalRef = db
    .collection(LIKES_COLLECTION)
    .doc(targetUid)
    .collection("targets")
    .doc(uid);

  await likeRef.set({
    likedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const reciprocal = await reciprocalRef.get();
  if (reciprocal.exists) {
    const matchRef = db.collection(MATCHES_COLLECTION).doc();
    await matchRef.set({
      members: [uid, targetUid],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: "active",
    });

    // Send notifications to both
    const hostName = targetProfile.data()?.name || "Someone";
    const likerName = (await db.collection(PROFILE_COLLECTION).doc(uid).get()).data()?.name || "Someone";

    await Promise.all([
      sendFCMNotification(uid, "It's a Match! 🧊", `You matched with ${hostName}!`),
      sendFCMNotification(targetUid, "It's a Match! 🧊", `You matched with ${likerName}!`),
    ]);

    return {matched: true, matchId: matchRef.id};
  }

  return {matched: false};
});

export const getMatches = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const snapshot = await db
    .collection(MATCHES_COLLECTION)
    .where("members", "array-contains", uid)
    .orderBy("createdAt", "desc")
    .limit(50)
    .get();

  const matches = snapshot.docs.map((doc) => ({id: doc.id, ...doc.data()}));
  return {matches};
});


export const sendMeltChatInvite = onCall(async (data, context) => {
  const hostUid = requireAuth(context);
  const targetUid =
    typeof data?.targetUid === "string" ? data.targetUid : null;
  const slotLabel =
    typeof data?.slotLabel === "string" ? data.slotLabel : null;

  if (!targetUid || !slotLabel) {
    throw new HttpsError(
      "invalid-argument",
      "targetUid and slotLabel are required",
    );
  }

  if (targetUid === hostUid) {
    throw new HttpsError(
      "failed-precondition",
      "Cannot invite yourself",
    );
  }

  const [hostProfile, targetProfile] = await Promise.all([
    db.collection(PROFILE_COLLECTION).doc(hostUid).get(),
    db.collection(PROFILE_COLLECTION).doc(targetUid).get(),
  ]);

  if (!hostProfile.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Host profile not found",
    );
  }
  if (!targetProfile.exists) {
    throw new HttpsError(
      "not-found",
      "Target profile not found",
    );
  }

  const existing = await db
    .collection(MELT_SESSIONS_COLLECTION)
    .where("hostUid", "==", hostUid)
    .where("targetUid", "==", targetUid)
    .where("status", "==", "active")
    .limit(1)
    .get();

  if (!existing.empty) {
    return {sessionId: existing.docs[0].id, resumed: true};
  }

  const sessionRef = db.collection(MELT_SESSIONS_COLLECTION).doc();
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    Date.now() + 60 * 60 * 1000,
  );

  await sessionRef.set({
    hostUid,
    targetUid,
    slotLabel,
    status: "active",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });

  await db.collection(CHATS_COLLECTION).doc(sessionRef.id).set({
    members: [hostUid, targetUid],
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {sessionId: sessionRef.id, resumed: false};
});

import * as geofire from "geofire-common";

// ── Notifications Helper ──────────────────────────────────────────────────
const sendFCMNotification = async (
  uid: string,
  title: string,
  body: string,
  data?: Record<string, string>,
) => {
  const userDoc = await db.collection("users").doc(uid).get();
  const fcmToken = userDoc.data()?.fcmToken;
  if (!fcmToken) return;

  await admin.messaging().send({
    token: fcmToken,
    notification: {title, body},
    data: data || {},
    apns: {payload: {aps: {sound: "default"}}},
  });
};

// ── Paths (Nearby) Optimized with Geohash ──────────────────────────────────
export const upsertPathsPresence = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const intents = Array.isArray(data?.intents) ?
    data.intents.filter((v: unknown) => typeof v === "string") :
    [];
  const radiusKm = typeof data?.radiusKm === "number" ? data.radiusKm : 10;
  const visibleUntil = typeof data?.visibleUntil === "string" ?
    new Date(data.visibleUntil) :
    new Date(Date.now() + 24 * 60 * 60 * 1000);

  const payload: Record<string, unknown> = {
    intents,
    radius_km: radiusKm,
    visible_until: admin.firestore.Timestamp.fromDate(visibleUntil),
    last_active_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Add geohash for radius search
  if (typeof data?.lat === "number" && typeof data?.lng === "number") {
    payload.lat = data.lat;
    payload.lng = data.lng;
    payload.geohash = geofire.geohashForLocation([data.lat, data.lng]);
  }

  await db.collection(PATHS_PRESENCE_COLLECTION)
    .doc(uid)
    .set(payload, {merge: true});
  return {ok: true};
});

export const getNearbyPaths = onCall(async (data, context) => {
  requireAuth(context);
  const originLat = typeof data?.lat === "number" ? data.lat : null;
  const originLng = typeof data?.lng === "number" ? data.lng : null;
  const radiusKm = typeof data?.radiusKm === "number" && data.radiusKm > 0 ?
    data.radiusKm :
    10;

  if (originLat === null || originLng === null) {
    throw new HttpsError("invalid-argument", "lat and lng are required");
  }

  const center: geofire.Geopoint = [originLat, originLng];
  const radiusInM = radiusKm * 1000;

  // Each item in 'bounds' represents a [startCode, endCode] range.
  const bounds = geofire.geohashQueryBounds(center, radiusInM);
  const promises = [];
  for (const b of bounds) {
    const q = db.collection(PATHS_PRESENCE_COLLECTION)
      .orderBy("geohash")
      .startAt(b[0])
      .endAt(b[1]);
    promises.push(q.get());
  }

  const snapshots = await Promise.all(promises);
  const now = Date.now();
  const profiles: any[] = [];

  for (const snap of snapshots) {
    for (const doc of snap.docs) {
      const d = doc.data();
      const lat = d.lat as number;
      const lng = d.lng as number;

      // Filter by real distance and visibility
      const distanceInKm = geofire.distanceBetween([lat, lng], center);
      const distanceInM = distanceInKm * 1000;
      const vu = (d.visible_until as admin.firestore.Timestamp | undefined)?.toMillis?.();

      if (distanceInM <= radiusInM && (!vu || vu > now)) {
        profiles.push({
          id: doc.id,
          ...d,
          distance: distanceInKm,
        });
      }
    }
  }

  // Sort by closest
  profiles.sort((a, b) => a.distance - b.distance);

  return {profiles: profiles.slice(0, 50)};
});


export const sendPathsInvite = onCall(async (data, context) => {
  const senderUid = requireAuth(context);
  const receiverUid = typeof data?.receiverUid === "string" ?
    data.receiverUid :
    null;
  const intent = typeof data?.intent === "string" ? data.intent : "either";
  if (!receiverUid) {
    throw new HttpsError("invalid-argument", "receiverUid is required");
  }
  const invite = {
    sender_uid: senderUid,
    receiver_uid: receiverUid,
    intent,
    status: "pending",
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  };
  const doc = await db.collection(PATH_INVITES_COLLECTION).add(invite);
  return {id: doc.id, status: "pending"};
});

export const respondPathsInvite = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const inviteId = typeof data?.inviteId === "string" ? data.inviteId : null;
  // accept/decline/cancel
  const action = typeof data?.action === "string" ? data.action : null;
  if (!inviteId || !action) {
    throw new HttpsError(
      "invalid-argument",
      "inviteId and action are required",
    );
  }
  const snap = await db
    .collection(PATH_INVITES_COLLECTION)
    .doc(inviteId)
    .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Invite not found");
  }
  const invite = snap.data() as Record<string, unknown>;
  const sender = invite.sender_uid as string | undefined;
  const receiver = invite.receiver_uid as string | undefined;
  if (uid !== sender && uid !== receiver) {
    throw new HttpsError("permission-denied", "Not a participant");
  }
  const status = action === "accept" ? "accepted" :
    action === "decline" ? "declined" :
      action === "cancel" ? "cancelled" : "pending";
  await snap.ref.set({
    status,
    responded_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  if (status === "accepted" && sender && receiver) {
    const chatId = [sender, receiver].sort().join("_");
    await db.collection(CHATS_COLLECTION).doc(chatId).set({
      participants: [sender, receiver],
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }
  return {status};
});

// -------------------- Blinds (anonymous chat) --------------------
export const enqueueBlind = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const intent = typeof data?.intent === "string" ? data.intent : "either";
  const distanceBucket = typeof data?.distanceBucket === "string" ?
    data.distanceBucket :
    "0-20km";
  const interests = Array.isArray(data?.interests) ?
    data.interests.filter((v: unknown) => typeof v === "string") :
    [];
  const availableUntil = typeof data?.availableUntil === "string" ?
    admin.firestore.Timestamp.fromDate(new Date(data.availableUntil)) :
    admin.firestore.Timestamp.fromDate(new Date(Date.now() + 15 * 60 * 1000));

  await db.collection(BLINDS_QUEUE_COLLECTION).doc(uid).set({
    intent,
    distance_bucket: distanceBucket,
    interests,
    available_until: availableUntil,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });
  return {ok: true};
});

export const dequeueBlind = onCall(async (data, context) => {
  const uid = requireAuth(context);
  await db.collection(BLINDS_QUEUE_COLLECTION).doc(uid).delete().catch(() => {
    // ignore missing doc
  });
  return {ok: true};
});

export const createBlindSession = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const partnerUid = typeof data?.partnerUid === "string" ?
    data.partnerUid :
    null;
  if (!partnerUid) {
    throw new HttpsError("invalid-argument", "partnerUid required");
  }
  const expiresAt = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() + 12 * 60 * 1000),
  );
  const sessionRef = db.collection(BLINDS_SESSIONS_COLLECTION).doc();
  await sessionRef.set({
    user_a: uid,
    user_b: partnerUid,
    phase: "anonymous",
    expires_at: expiresAt,
    reveal_a: false,
    reveal_b: false,
    reported: false,
  });
  await db.collection(BLINDS_QUEUE_COLLECTION).doc(uid).delete().catch(() => {
    // ignore
  });
  await db
    .collection(BLINDS_QUEUE_COLLECTION)
    .doc(partnerUid)
    .delete()
    .catch(() => {
      // ignore
    });
  return {sessionId: sessionRef.id};
});

export const reportBlindSession = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const sessionId = typeof data?.sessionId === "string" ?
    data.sessionId :
    null;
  const reason = typeof data?.reason === "string" ?
    data.reason :
    "unspecified";
  if (!sessionId) {
    throw new HttpsError("invalid-argument", "sessionId required");
  }
  const snap = await db
    .collection(BLINDS_SESSIONS_COLLECTION)
    .doc(sessionId)
    .get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Session not found");
  }
  const session = snap.data() as Record<string, unknown>;
  if (session.user_a !== uid && session.user_b !== uid) {
    throw new HttpsError("permission-denied", "Not a participant");
  }
  await snap.ref.set({
    reported: true,
    report_reason: reason,
    reported_at: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return {ok: true};
});

// ═════════════════════════════════════════════════════════════════════════════
// Phase 2 — Receipt Verification  (Firebase Functions v2 + Secret Manager)
// ═════════════════════════════════════════════════════════════════════════════

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

interface MembershipRecord {
  platform: "ios" | "android";
  productId: string;
  active: boolean;
  expiry: admin.firestore.Timestamp | null;
  environment: "production" | "sandbox";
  updatedAt: admin.firestore.FieldValue;
}

const writeMembership = async (
  uid: string,
  record: MembershipRecord,
): Promise<void> => {
  await db
    .collection(MEMBERSHIPS_COLLECTION)
    .doc(uid)
    .set(record, {merge: true});
};

// ---------------------------------------------------------------------------
// Apple App Store receipt verification
//
// Called from the Flutter in_app_purchase plugin after a purchase completes.
// Payload: { productId: string, verificationData: { serverVerificationData: string } }
// Returns: { valid: boolean, expiry: string | null, environment: string }
// ---------------------------------------------------------------------------

const APPLE_PRODUCTION_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_URL = "https://sandbox.itunes.apple.com/verifyReceipt";

interface AppleVerifyResponse {
  status: number;
  latest_receipt_info?: Array<{
    product_id: string;
    expires_date_ms: string;
    cancellation_date_ms?: string;
  }>;
  receipt?: {bundle_id: string};
}

const callAppleEndpoint = async (
  url: string,
  receiptData: string,
  sharedSecret: string,
): Promise<AppleVerifyResponse> => {
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      "receipt-data": receiptData,
      "password": sharedSecret,
      "exclude-old-transactions": true,
    }),
  });
  if (!res.ok) {
    throw new Error(`Apple endpoint ${url} returned HTTP ${res.status}`);
  }
  return res.json() as Promise<AppleVerifyResponse>;
};

export const verifyApplePurchase = onCallV2(
  {secrets: [secretAppleSharedSecret]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsErrorV2("unauthenticated", "Authentication required");
    }
    const uid = request.auth.uid;

    const productId =
      typeof request.data?.productId === "string" ?
        request.data.productId :
        null;
    const receiptData =
      typeof request.data?.verificationData?.serverVerificationData === "string" ?
        request.data.verificationData.serverVerificationData :
        null;

    if (!productId || !receiptData) {
      throw new HttpsErrorV2(
        "invalid-argument",
        "productId and verificationData.serverVerificationData are required",
      );
    }

    const sharedSecret = secretAppleSharedSecret.value();

    // Try production first. Apple returns status 21007 when a sandbox receipt
    // hits the production endpoint — retry against sandbox automatically.
    let response = await callAppleEndpoint(
      APPLE_PRODUCTION_URL,
      receiptData,
      sharedSecret,
    ).catch((err: Error) => {
      throw new HttpsErrorV2(
        "internal",
        `Apple request failed: ${err.message}`,
      );
    });

    let environment: "production" | "sandbox" = "production";
    if (response.status === 21007) {
      response = await callAppleEndpoint(
        APPLE_SANDBOX_URL,
        receiptData,
        sharedSecret,
      ).catch((err: Error) => {
        throw new HttpsErrorV2(
          "internal",
          `Apple sandbox request failed: ${err.message}`,
        );
      });
      environment = "sandbox";
    }

    // Status 0 = valid. Status 21006 = expired but receipt is authentic — we
    // still record it so the client knows the subscription lapsed cleanly.
    if (response.status !== 0 && response.status !== 21006) {
      console.error("Apple verification rejected", {uid, status: response.status});
      throw new HttpsErrorV2(
        "failed-precondition",
        `Apple receipt invalid (status ${response.status})`,
      );
    }

    // Find the most-recent non-cancelled transaction for this productId.
    const transactions = (response.latest_receipt_info ?? [])
      .filter((t) => t.product_id === productId && !t.cancellation_date_ms);
    transactions.sort(
      (a, b) => Number(b.expires_date_ms) - Number(a.expires_date_ms),
    );
    const latest = transactions[0];

    const expiryMs = latest ? Number(latest.expires_date_ms) : null;
    const isActive = Boolean(expiryMs && expiryMs > Date.now());

    await writeMembership(uid, {
      platform: "ios",
      productId,
      active: isActive,
      expiry: expiryMs ?
        admin.firestore.Timestamp.fromMillis(expiryMs) :
        null,
      environment,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      valid: isActive,
      expiry: expiryMs ? new Date(expiryMs).toISOString() : null,
      environment,
    };
  },
);

// ---------------------------------------------------------------------------
// Google Play subscription verification  (v2 — reads from Secret Manager)
//
// Replaces the v1 verifyAndroidPurchase. Deploy both during the migration
// period, then retire the v1 version once clients have been updated.
// Payload: { productId: string, verificationData: { serverVerificationData: string } }
// Returns: { valid: boolean, expiry: string | null }
// ---------------------------------------------------------------------------

let cachedPublisherV2: androidPublisherV3.Androidpublisher | null = null;

const getAndroidPublisherClientV2 = async (
  serviceAccountJson: string,
): Promise<androidPublisherV3.Androidpublisher> => {
  if (cachedPublisherV2) return cachedPublisherV2;

  let credentials: {client_email: string; private_key: string};
  try {
    credentials = JSON.parse(serviceAccountJson);
  } catch (err) {
    throw new HttpsErrorV2(
      "invalid-argument",
      `PLAY_SERVICE_ACCOUNT secret is not valid JSON: ${(err as Error).message}`,
    );
  }

  const auth = new google.auth.JWT({
    email: credentials.client_email,
    key: credentials.private_key.replace(/\\n/g, "\n"),
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  await auth.authorize();
  cachedPublisherV2 = google.androidpublisher({version: "v3", auth});
  return cachedPublisherV2;
};

export const verifyAndroidPurchaseV2 = onCallV2(
  {secrets: [secretPlayServiceAccount, secretPlayPackageName]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsErrorV2("unauthenticated", "Authentication required");
    }
    const uid = request.auth.uid;

    const productId =
      typeof request.data?.productId === "string" ?
        request.data.productId :
        null;
    const purchaseToken =
      typeof request.data?.verificationData?.serverVerificationData === "string" ?
        request.data.verificationData.serverVerificationData :
        null;

    if (!productId || !purchaseToken) {
      throw new HttpsErrorV2(
        "invalid-argument",
        "productId and verificationData.serverVerificationData are required",
      );
    }

    const pkg = secretPlayPackageName.value();
    const androidPublisher = await getAndroidPublisherClientV2(
      secretPlayServiceAccount.value(),
    );

    try {
      const {data: subscription} =
        await androidPublisher.purchases.subscriptions.get({
          packageName: pkg,
          subscriptionId: productId,
          token: purchaseToken,
        });

      const expiryMillis = subscription.expiryTimeMillis ?
        Number(subscription.expiryTimeMillis) :
        null;
      const isAcknowledged = subscription.acknowledgementState === 1;
      const cancelReason = Number(subscription.cancelReason ?? 0);
      const now = Date.now();
      const isActive =
        Boolean(expiryMillis && expiryMillis > now) && cancelReason === 0;

      // Acknowledge so Google doesn't auto-refund after 3 days.
      if (isActive && !isAcknowledged) {
        await androidPublisher.purchases.subscriptions.acknowledge({
          packageName: pkg,
          subscriptionId: productId,
          token: purchaseToken,
          requestBody: {developerPayload: `ack-${uid}-${productId}`},
        });
      }

      await writeMembership(uid, {
        platform: "android",
        productId,
        active: isActive,
        expiry: expiryMillis ?
          admin.firestore.Timestamp.fromMillis(expiryMillis) :
          null,
        environment: "production",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {
        valid: isActive,
        expiry: expiryMillis ? new Date(expiryMillis).toISOString() : null,
      };
    } catch (error) {
      console.error("verifyAndroidPurchaseV2 failed", error);
      throw new HttpsErrorV2(
        "internal",
        "Failed to verify purchase with Google Play",
      );
    }
  },
);
