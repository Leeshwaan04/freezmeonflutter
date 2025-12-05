const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

/**
 * getTonightPool - Returns profiles active in the last 3 hours within a geo-radius
 */
exports.getTonightPool = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
  }

  const { lat, lng, timezone } = data;
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
    throw new functions.https.HttpsError("internal", "Failed to fetch tonight pool");
  }
});

/**
 * updateUserPreferences - Saves user preferences to Firestore
 */
exports.updateUserPreferences = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
  }

  const { ageMin, ageMax, distanceKm, bio } = data;
  const uid = context.auth.uid;

  try {
    await db.collection("users").doc(uid).set(
      {
        preferences: { ageMin, ageMax, distanceKm },
        bio,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
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
 * acceptPathInvite - Handles Paths invite acceptance
 */
exports.acceptPathInvite = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be signed in");
  }

  const { inviteId } = data;
  const uid = context.auth.uid;

  try {
    const inviteRef = db.collection("path_invites").doc(inviteId);
    const inviteDoc = await inviteRef.get();

    if (!inviteDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Invite not found");
    }

    const inviteData = inviteDoc.data();
    if (inviteData.receiver_uid !== uid) {
      throw new functions.https.HttpsError("permission-denied", "Not your invite");
    }

    // Update invite status
    await inviteRef.update({
      status: "accepted",
      acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Add user to path participants
    const pathRef = db.collection("paths").doc(inviteData.path_id);
    await pathRef.update({
      participants: admin.firestore.FieldValue.arrayUnion(uid),
    });

    return { success: true, pathId: inviteData.path_id };
  } catch (error) {
    console.error("Error accepting invite:", error);
    throw new functions.https.HttpsError("internal", "Failed to accept invite");
  }
});

/**
 * sendPushNotification - Sends push notifications
 */
exports.sendPushNotification = functions.firestore
  .document("chats/{chatId}/messages/{messageId}")
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const { chatId } = context.params;

    try {
      // Get chat members
      const chatDoc = await db.collection("chats").doc(chatId).get();
      if (!chatDoc.exists) return;

      const chatData = chatDoc.data();
      const recipientUid = chatData.members.find((m) => m !== message.senderUid);

      if (!recipientUid) return;

      // Get recipient's FCM token
      const userDoc = await db.collection("users").doc(recipientUid).get();
      if (!userDoc.exists) return;

      const fcmToken = userDoc.data().fcmToken;
      if (!fcmToken) return;

      // Send notification
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
