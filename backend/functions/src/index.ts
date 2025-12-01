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

const haversineKm = (
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number,
): number => {
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return 6371 * c; // Earth radius km
};

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

const packageName = process.env.PLAY_BILLING_PACKAGE_NAME;

let cachedPublisher:
  | androidPublisherV3.Androidpublisher
  | null = null;

const getAndroidPublisherClient = async () => {
  if (cachedPublisher) return cachedPublisher;

  const serviceAccountJson = process.env.PLAY_SERVICE_ACCOUNT;
  if (!serviceAccountJson) {
    throw new HttpsError(
      "failed-precondition",
      "PLAY_SERVICE_ACCOUNT env var is not set",
    );
  }

  if (!packageName) {
    throw new HttpsError(
      "failed-precondition",
      "PLAY_BILLING_PACKAGE_NAME env var is not set",
    );
  }

  let credentials: {client_email: string; private_key: string};
  try {
    credentials = JSON.parse(serviceAccountJson);
  } catch (error) {
    throw new HttpsError(
      "invalid-argument",
      `PLAY_SERVICE_ACCOUNT must be valid JSON: ${(error as Error).message}`,
    );
  }

  const auth = new google.auth.JWT({
    email: credentials.client_email,
    key: credentials.private_key.replace(/\\n/g, "\n"),
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });

  await auth.authorize();
  cachedPublisher = google.androidpublisher({version: "v3", auth});
  return cachedPublisher;
};

export const createProfile = onCall(async (data, context) => {
  const uid = requireAuth(context);
  const profile = sanitizeProfile(data);

  await db.collection(PROFILE_COLLECTION).doc(uid).set(
    {
      ...profile,
      uid,
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

export const verifyAndroidPurchase = onCall(async (data, context) => {
  const uid = requireAuth(context);

  if (!packageName) {
    throw new HttpsError(
      "failed-precondition",
      "PLAY_BILLING_PACKAGE_NAME env var must be configured",
    );
  }

  const productId = typeof data?.productId === "string" ? data.productId : null;
  const hasVerificationData =
    typeof data?.verificationData === "object" &&
    data.verificationData !== null;
  const verificationData = hasVerificationData ?
    data.verificationData as Record<string, unknown> :
    null;

  let purchaseToken: string | null = null;
  if (typeof verificationData?.serverVerificationData === "string") {
    purchaseToken = verificationData.serverVerificationData as string;
  }

  if (!productId || !purchaseToken) {
    throw new HttpsError(
      "invalid-argument",
      "productId and verificationData.serverVerificationData are required",
    );
  }

  const androidPublisher = await getAndroidPublisherClient();

  try {
    const response = await androidPublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: productId,
      token: purchaseToken,
    });

    const subscription = response.data;
    const expiryMillis = subscription.expiryTimeMillis ?
      Number(subscription.expiryTimeMillis) :
      null;
    const isAcknowledged = subscription.acknowledgementState === 1;
    // cancelReason: 0 = active, >0 = cancelled/refunded
    const cancelReason = Number(subscription.cancelReason ?? 0);

    const now = Date.now();
    const isActive =
      Boolean(expiryMillis && expiryMillis > now) &&
      cancelReason === 0;

    if (isActive && !isAcknowledged) {
      await androidPublisher.purchases.subscriptions.acknowledge({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
        requestBody: {developerPayload: `ack-${uid}-${productId}`},
      });
    }

    await db.collection(MEMBERSHIPS_COLLECTION).doc(uid).set(
      {
        productId,
        active: isActive,
        expiry: expiryMillis ?
          admin.firestore.Timestamp.fromMillis(expiryMillis) :
          null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true},
    );

    return {
      valid: isActive,
      expiry: expiryMillis ? new Date(expiryMillis).toISOString() : null,
    };
  } catch (error) {
    console.error(
      "verifyAndroidPurchase failed",
      error,
    );
    throw new HttpsError(
      "internal",
      "Failed to verify purchase with Google Play",
    );
  }
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

// -------------------- Paths (Nearby) --------------------
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
  if (typeof data?.lat === "number" && typeof data?.lng === "number") {
    payload.lat = data.lat;
    payload.lng = data.lng;
  }
  if (typeof data?.geohash === "string") {
    payload.geohash = data.geohash;
  }
  if (typeof data?.availability === "string") {
    payload.availability = data.availability;
  }
  if (typeof data?.interestsSummary === "string") {
    payload.interests = data.interestsSummary;
  }

  await db.collection(PATHS_PRESENCE_COLLECTION)
    .doc(uid)
    .set(payload, {merge: true});
  return {ok: true};
});

export const getNearbyPaths = onCall(async (data, context) => {
  requireAuth(context);
  const intents = Array.isArray(data?.intents) ?
    data.intents.filter((v: unknown) => typeof v === "string") :
    [];
  const originLat = typeof data?.lat === "number" ? data.lat : null;
  const originLng = typeof data?.lng === "number" ? data.lng : null;
  const maxRadius = typeof data?.radiusKm === "number" && data.radiusKm > 0 ?
    data.radiusKm :
    50;
  // NOTE: Replace with real geohash/radius filtering in production.
  let ref = db.collection(PATHS_PRESENCE_COLLECTION)
    .orderBy("last_active_at", "desc")
    .limit(50);
  if (intents.length > 0) {
    ref = ref.where("intents", "array-contains-any", intents);
  }
  const snapshot = await ref.get();
  const now = Date.now();
  const profiles = snapshot.docs
    .map((doc) => ({
      id: doc.id,
      data: doc.data() as Record<string, unknown>,
    }))
    .filter(({data}) => {
      const vu = (data.visible_until as admin.firestore.Timestamp |
        undefined)?.toMillis?.();
      if (vu && vu <= now) return false;
      if (originLat !== null && originLng !== null &&
        typeof data.lat === "number" &&
        typeof data.lng === "number") {
        const distance = haversineKm(
          originLat,
          originLng,
          data.lat as number,
          data.lng as number,
        );
        return distance <= maxRadius;
      }
      return true;
    })
    .map(({id, data}) => ({id, ...data}));
  return {profiles};
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
