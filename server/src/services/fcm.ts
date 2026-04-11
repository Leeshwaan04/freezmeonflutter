import admin from 'firebase-admin';
import fs from 'fs';
import { prisma } from '../db/client';
import { logger } from './logger';

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

// FCM error codes that mean the token is permanently invalid and should be removed
const STALE_TOKEN_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
  'messaging/invalid-argument',
]);

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
  } catch (err: any) {
    const code: string = err?.errorInfo?.code ?? err?.code ?? '';
    if (STALE_TOKEN_CODES.has(code)) {
      // Token is permanently invalid — clear it so we don't keep trying
      logger.warn({ msg: 'fcm_stale_token', code, token: fcmToken.slice(-8) });
      await prisma.user.updateMany({
        where: { fcmToken },
        data: { fcmToken: null },
      }).catch(() => {});
    } else {
      logger.error({ msg: 'fcm_send_failed', code, error: err?.message });
    }
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
