"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.sendPushNotification = sendPushNotification;
exports.sendMatchNotification = sendMatchNotification;
exports.sendMeltInviteNotification = sendMeltInviteNotification;
const firebase_admin_1 = __importDefault(require("firebase-admin"));
const fs_1 = __importDefault(require("fs"));
let initialized = false;
function initFirebaseAdmin() {
    if (initialized)
        return;
    const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (!serviceAccountPath || !fs_1.default.existsSync(serviceAccountPath)) {
        console.warn('[FCM] Firebase service account not found — push notifications disabled');
        return;
    }
    const serviceAccount = JSON.parse(fs_1.default.readFileSync(serviceAccountPath, 'utf-8'));
    firebase_admin_1.default.initializeApp({ credential: firebase_admin_1.default.credential.cert(serviceAccount) });
    initialized = true;
    console.log('[FCM] Firebase Admin initialized for push notifications');
}
initFirebaseAdmin();
async function sendPushNotification(fcmToken, title, body, data) {
    if (!initialized)
        return;
    try {
        await firebase_admin_1.default.messaging().send({
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
    }
    catch (err) {
        console.error('[FCM] Failed to send push notification:', err);
    }
}
async function sendMatchNotification(fcmToken, matcherName) {
    await sendPushNotification(fcmToken, "It's a Match!", `You and ${matcherName} liked each other.`, { type: 'match' });
}
async function sendMeltInviteNotification(fcmToken, senderName) {
    await sendPushNotification(fcmToken, 'Melt Invite', `${senderName} wants to connect with you.`, { type: 'melt_invite' });
}
//# sourceMappingURL=fcm.js.map