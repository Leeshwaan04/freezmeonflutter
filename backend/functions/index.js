const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

/**
 * getTonightPool - Returns profiles active in the last 3 hours
 */
exports.getTonightPool = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
  }

  const { lat, lng } = data; // Unused for now, but good for future geo-querying
  const threeHoursAgo = new Date(Date.now() - 3 * 60 * 60 * 1000);

  try {
    const snapshot = await db
      .collection("profiles")
      .where("lastActive", ">", threeHoursAgo.toISOString())
      .limit(50)
      .get();

    const profiles = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { profiles };
  } catch (error) {
    console.error("Error fetching tonight pool:", error);
    // Return empty list instead of throwing to prevent app crash if index missing
    return { profiles: [] };
  }
});

/**
 * updateUserPreferences - Saves user preferences
 */
exports.updateUserPreferences = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
  }

  const { ageMin, ageMax, distanceKm, bio, interests } = data;
  const uid = context.auth.uid;

  try {
    await db.collection("users").doc(uid).set(
      {
        preferences: { ageMin, ageMax, distanceKm },
        bio,
        interests,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
    // Also update public profile
    await db.collection("profiles").doc(uid).set(
      {
        bio,
        interests,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { success: true };
  } catch (error) {
    console.error("Error updating preferences:", error);
    throw new functions.https.HttpsError("internal", "Failed to update preferences");
  }
});

/**
 * upsertPathsPresence - Updates user's active status in Paths
 */
exports.upsertPathsPresence = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");

  const uid = context.auth.uid;
  const { intents, radiusKm, visibleUntil, lat, lng, geohash, availability, interestsSummary } = data;

  try {
    await db.collection('paths_presence').doc(uid).set({
      uid,
      intents,
      radiusKm,
      visibleUntil: new Date(visibleUntil),
      lat,
      lng,
      geohash,
      availability,
      interestsSummary,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  } catch (e) {
    console.error("Error upserting presence:", e);
    throw new functions.https.HttpsError("internal", e.message);
  }
});

/**
 * getNearbyPaths - Fetches nearby active presences using geohashes
 */
exports.getNearbyPaths = functions.https.onCall(async (data, context) => {
  const { radiusKm, lat, lng, intents } = data;

  try {
    const now = new Date();
    let query = db.collection('paths_presence')
      .where('visibleUntil', '>', now);

    // Filter by intent if provided
    if (intents && intents.length > 0) {
      query = query.where('intents', 'array-contains-any', intents);
    }

    const snapshot = await query.limit(50).get();
    let profiles = snapshot.docs.map(doc => ({ ...doc.data(), id: doc.id }));

    // Client-side distance filtering for better precision if lat/lng available
    if (lat && lng) {
      profiles = profiles.filter(p => {
        if (!p.lat || !p.lng) return false;
        const d = calculateDistance(lat, lng, p.lat, p.lng);
        return d <= (radiusKm || 10);
      });
    }

    return { profiles: profiles.slice(0, 20) };
  } catch (error) {
    console.error("Error fetching nearby paths:", error);
    return { profiles: [] };
  }
});

function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * sendPathsInvite - Sends an invite to a nearby user
 */
exports.sendPathsInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { receiverUid, intent } = data;
  const senderUid = context.auth.uid;

  try {
    const ref = await db.collection('path_invites').add({
      senderUid,
      receiverUid,
      intent,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { id: ref.id };
  } catch (e) {
    console.error("Error sending invite:", e);
    throw new functions.https.HttpsError("internal", "Failed to send invite");
  }
});

/**
 * respondPathsInvite - Accept or Cancel
 */
exports.respondPathsInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { inviteId, action } = data; // 'accept' or 'cancel' or 'decline'

  try {
    await db.collection('path_invites').doc(inviteId).update({
      status: action === 'cancel' ? 'cancelled' : (action === 'accept' ? 'accepted' : 'declined'),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true };
  } catch (e) {
    throw new functions.https.HttpsError("internal", "Failed to respond");
  }
});

/**
 * enqueueBlind - Adapts to Blinds queue
 */
exports.enqueueBlind = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { intent, distanceBucket, availableUntil } = data;
  const uid = context.auth.uid;

  try {
    await db.collection('blind_queue').doc(uid).set({
      uid,
      intent,
      distanceBucket,
      availableUntil: new Date(availableUntil),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'waiting'
    });
    return { success: true };
  } catch (e) {
    throw new functions.https.HttpsError("internal", "Failed to enqueue");
  }
});

/**
 * matchBlindUsers - Automatic trigger to match users in blind queue
 */
exports.matchBlindUsers = functions.firestore
  .document('blind_queue/{uid}')
  .onCreate(async (snap, context) => {
    const newUser = snap.data();
    const uid = context.params.uid;

    const others = await db.collection('blind_queue')
      .where('status', '==', 'waiting')
      .where('intent', '==', newUser.intent)
      .where('distanceBucket', '==', newUser.distanceBucket)
      .limit(5)
      .get();

    for (const doc of others.docs) {
      if (doc.id === uid) continue;

      const otherUser = doc.data();
      const sessionId = [uid, doc.id].sort().join('_');

      // Atomic match creation
      const batch = db.batch();
      batch.set(db.collection('blind_sessions').doc(sessionId), {
        hostUid: uid,
        targetUid: doc.id,
        intent: newUser.intent,
        status: 'active',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: newUser.availableUntil,
      });
      batch.delete(db.collection('blind_queue').doc(uid));
      batch.delete(db.collection('blind_queue').doc(doc.id));

      await batch.commit();
      console.log(`Matched ${uid} with ${doc.id}`);
      return; // done
    }
  });

/**
 * dequeueBlind - Leaves the queue
 */
exports.dequeueBlind = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  await db.collection('blind_queue').doc(context.auth.uid).delete();
  return { success: true };
});

/**
 * createBlindSession - Creates a session (usually called by matching logic)
 */
exports.createBlindSession = functions.https.onCall(async (data, context) => {
  // This arguably should be server-side logic only, but for dev we might allow it
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { partnerUid } = data;
  const uid = context.auth.uid;

  // Create chat
  const ref = await db.collection('blinds_sessions').add({
    userA: uid,
    userB: partnerUid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'active',
  });

  return { sessionId: ref.id };
});

/**
 * reportBlindSession
 */
exports.reportBlindSession = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { sessionId, reason } = data;

  await db.collection('reports').add({
    reporter: context.auth.uid,
    type: 'blind_session',
    targetId: sessionId,
    reason,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

/**
 * sendMeltChatInvite - Sends a semi-anonymous invite to unfreeze a connection
 */
exports.sendMeltChatInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { targetUid, slot } = data;
  const senderUid = context.auth.uid;

  try {
    const inviteRef = await db.collection("melt_invites").add({
      senderUid,
      targetUid,
      slot,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // In a real app, send a push notification here
    // ...

    return { success: true, inviteId: inviteRef.id };
  } catch (error) {
    console.error("Error sending melt invite:", error);
    throw new functions.https.HttpsError("internal", "Failed to send melt invite");
  }
});

/**
 * respondMeltChatInvite - Accept or Decline a melt invite and create a chat session
 */
exports.respondMeltChatInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) throw new functions.https.HttpsError("unauthenticated", "Auth required");
  const { inviteId, response } = data; // 'accept' or 'decline'
  const uid = context.auth.uid;

  try {
    const inviteDoc = await db.collection("melt_invites").doc(inviteId).get();
    if (!inviteDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Invite not found");
    }

    const inviteData = inviteDoc.data();
    if (inviteData.targetUid !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Not your invite");
    }

    if (response === "decline") {
      await inviteDoc.ref.update({ status: "declined" });
      return { success: true };
    }

    // Accept - Create the Chat Session
    const chatId = [inviteData.senderUid, uid].sort().join("_");

    // Create actual chat document
    await db.collection("chats").doc(chatId).set({
      members: [inviteData.senderUid, uid],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastMessage: {
        text: "The ice has melted! Say hello.",
        senderId: "system",
        status: "sent",
      },
      memberDisplay: {
        [inviteData.senderUid]: { name: "Sender" }, // In real app, fetch from user profiles
        [uid]: { name: "Receiver" },
      }
    }, { merge: true });

    await inviteDoc.ref.update({ status: "accepted", chatId });

    return { success: true, chatId };
  } catch (error) {
    console.error("Error responding to melt invite:", error);
    throw new functions.https.HttpsError("internal", "Failed to respond to invite");
  }
});

// Existing push notification logic
exports.sendPushNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { chatId } = context.params;

    try {
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data();
      const recipientUid = chatData.members.find((m) => m !== message.senderUid);

      if (!recipientUid) return;

      const userDoc = await db.collection("users").doc(recipientUid).get();
      if (!userDoc.exists) return;

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) return;

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: message.senderName || "New Message",
          body: message.text || "You have a new message",
        },
        data: {
          chatId,
          type: "chat_message",
        },
      });
    } catch (error) {
      console.error("Error sending push notification:", error);
    }
  });
