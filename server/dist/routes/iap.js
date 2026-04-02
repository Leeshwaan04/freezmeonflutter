"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const client_1 = require("../db/client");
const https_1 = __importDefault(require("https"));
const googleapis_1 = require("googleapis");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// POST /iap/verify-apple — replaces verifyApplePurchase Cloud Function
router.post('/verify-apple', async (req, res) => {
    try {
        const { receiptData, productId } = req.body;
        if (!receiptData || !productId) {
            res.status(400).json({ error: 'receiptData and productId required' });
            return;
        }
        const sharedSecret = process.env.APPLE_SHARED_SECRET;
        const payload = JSON.stringify({ 'receipt-data': receiptData, password: sharedSecret });
        const verifyWithApple = (url) => new Promise((resolve, reject) => {
            const options = {
                hostname: url,
                path: '/verifyReceipt',
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
            };
            const appleReq = https_1.default.request(options, (appleRes) => {
                let data = '';
                appleRes.on('data', (chunk) => (data += chunk));
                appleRes.on('end', () => resolve(JSON.parse(data)));
            });
            appleReq.on('error', reject);
            appleReq.write(payload);
            appleReq.end();
        });
        let result = await verifyWithApple('buy.itunes.apple.com');
        // Sandbox fallback (status 21007)
        if (result.status === 21007) {
            result = await verifyWithApple('sandbox.itunes.apple.com');
        }
        if (result.status !== 0) {
            res.status(400).json({ error: 'Invalid receipt', status: result.status });
            return;
        }
        const latestReceipt = result.latest_receipt_info?.[0];
        const expiryMs = latestReceipt?.expires_date_ms ? parseInt(latestReceipt.expires_date_ms) : null;
        const expiry = expiryMs ? new Date(expiryMs) : null;
        const active = expiry ? expiry > new Date() : true;
        const environment = result.environment === 'Sandbox' ? 'sandbox' : 'production';
        await client_1.prisma.membership.upsert({
            where: { userId: req.uid },
            update: { platform: 'ios', productId, active, expiry, environment, updatedAt: new Date() },
            create: { userId: req.uid, platform: 'ios', productId, active, expiry, environment },
        });
        await client_1.prisma.profile.update({
            where: { userId: req.uid },
            data: { isPremium: active },
        });
        res.json({ success: true, active, expiry });
    }
    catch (err) {
        console.error('[iap/verify-apple]', err);
        res.status(500).json({ error: 'Apple verification failed' });
    }
});
// POST /iap/verify-android — replaces verifyAndroidPurchaseV2 Cloud Function
router.post('/verify-android', async (req, res) => {
    try {
        const { purchaseToken, productId, subscriptionId } = req.body;
        if (!purchaseToken || !productId) {
            res.status(400).json({ error: 'purchaseToken and productId required' });
            return;
        }
        const serviceAccountJson = JSON.parse(process.env.PLAY_SERVICE_ACCOUNT_JSON ?? '{}');
        const packageName = process.env.PLAY_BILLING_PACKAGE_NAME;
        const auth = new googleapis_1.google.auth.GoogleAuth({
            credentials: serviceAccountJson,
            scopes: ['https://www.googleapis.com/auth/androidpublisher'],
        });
        const androidpublisher = googleapis_1.google.androidpublisher({ version: 'v3', auth });
        const response = await androidpublisher.purchases.subscriptions.get({
            packageName,
            subscriptionId: subscriptionId ?? productId,
            token: purchaseToken,
        });
        const sub = response.data;
        const expiry = sub.expiryTimeMillis ? new Date(parseInt(sub.expiryTimeMillis)) : null;
        const active = expiry ? expiry > new Date() : false;
        // Acknowledge if needed
        if (sub.acknowledgementState === 0) {
            await androidpublisher.purchases.subscriptions.acknowledge({
                packageName,
                subscriptionId: subscriptionId ?? productId,
                token: purchaseToken,
                requestBody: {},
            });
        }
        await client_1.prisma.membership.upsert({
            where: { userId: req.uid },
            update: { platform: 'android', productId, active, expiry, environment: 'production', updatedAt: new Date() },
            create: { userId: req.uid, platform: 'android', productId, active, expiry, environment: 'production' },
        });
        await client_1.prisma.profile.update({
            where: { userId: req.uid },
            data: { isPremium: active },
        });
        res.json({ success: true, active, expiry });
    }
    catch (err) {
        console.error('[iap/verify-android]', err);
        res.status(500).json({ error: 'Android verification failed' });
    }
});
exports.default = router;
//# sourceMappingURL=iap.js.map