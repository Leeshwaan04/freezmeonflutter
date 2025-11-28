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
