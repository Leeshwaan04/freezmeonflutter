import admin from 'firebase-admin';
import path from 'path';
import fs from 'fs';

let initialized = false;

function initFirebaseAdmin(): void {
  if (initialized) return;

  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!serviceAccountPath || !fs.existsSync(serviceAccountPath)) {
    console.warn('[FCM] Firebase service account not found — push notifications disabled');
    return;
  }

  const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf-8'));
  admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  initialized = true;
  console.log('[FCM] Firebase Admin initialized for push notifications');
}

initFirebaseAdmin();

export async function sendPushNotification(
  fcmToken: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  if (!initialized) return;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body },
      data,
      apns: {
        payload: { aps: { sound: 'default', badge: 1 } },
      },
      android: {
        priority: 'high',
        notification: { sound: 'default' },
      },
    });
  } catch (err) {
    console.error('[FCM] Failed to send push notification:', err);
  }
}

export async function sendMatchNotification(fcmToken: string, matcherName: string): Promise<void> {
  await sendPushNotification(
    fcmToken,
    "It's a Match!",
    `You and ${matcherName} liked each other.`,
    { type: 'match' }
  );
}

export async function sendMeltInviteNotification(fcmToken: string, senderName: string): Promise<void> {
  await sendPushNotification(
    fcmToken,
    'Melt Invite',
    `${senderName} wants to connect with you.`,
    { type: 'melt_invite' }
  );
}
