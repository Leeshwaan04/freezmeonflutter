import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import https from 'https';
import { google } from 'googleapis';

const router = Router();
router.use(requireAuth);

// ── Apple receipt verification helper ──────────────────────────────────────────
function verifyWithApple(hostname: string, payload: string): Promise<any> {
  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname,
        path: '/verifyReceipt',
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          try { resolve(JSON.parse(data)); }
          catch { reject(new Error('Invalid JSON from Apple')); }
        });
      },
    );
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

// POST /iap/verify-apple
router.post('/verify-apple', async (req: Request, res: Response) => {
  try {
    const { receiptData, productId } = req.body;
    if (!receiptData || !productId) {
      res.status(400).json({ error: 'receiptData and productId required' }); return;
    }

    const sharedSecret = process.env.APPLE_SHARED_SECRET;
    if (!sharedSecret) {
      console.error('[iap/verify-apple] APPLE_SHARED_SECRET not set');
      res.status(500).json({ error: 'Payment configuration error' }); return;
    }

    const isProduction = process.env.NODE_ENV === 'production';
    const payload = JSON.stringify({ 'receipt-data': receiptData, password: sharedSecret });

    // SECURITY: Always verify against production first.
    // status 21007 = sandbox receipt — reject in production (never trust client-supplied isSandbox flag).
    // In dev/staging, fall back to sandbox endpoint.
    let result = await verifyWithApple('buy.itunes.apple.com', payload);
    if (result.status === 21007) {
      if (isProduction) {
        // Hard reject sandbox receipts in production regardless of client flags
        console.warn('[iap/verify-apple] Sandbox receipt rejected in production, uid:', req.uid);
        res.status(400).json({ error: 'Sandbox receipt not accepted in production' }); return;
      }
      result = await verifyWithApple('sandbox.itunes.apple.com', payload);
    }

    if (result.status !== 0) {
      console.warn('[iap/verify-apple] Apple status:', result.status, 'uid:', req.uid);
      res.status(400).json({ error: 'Invalid receipt', appleStatus: result.status }); return;
    }

    // Find the most recent receipt for this productId
    const receipts: any[] = result.latest_receipt_info ?? [];
    const matching = receipts
      .filter((r: any) => r.product_id === productId)
      .sort((a: any, b: any) => parseInt(b.expires_date_ms ?? '0') - parseInt(a.expires_date_ms ?? '0'));

    const latestReceipt = matching[0] ?? receipts[0];
    const expiryMs = latestReceipt?.expires_date_ms ? parseInt(latestReceipt.expires_date_ms) : null;
    const expiry = expiryMs ? new Date(expiryMs) : null;
    const active = expiry ? expiry > new Date() : false;
    const environment = result.environment === 'Sandbox' ? 'sandbox' : 'production';
    const originalTransactionId: string | undefined = latestReceipt?.original_transaction_id;

    // SECURITY: Prevent receipt replay — check if this transaction ID is already
    // used by a different user.
    if (originalTransactionId) {
      const existingMembership = await prisma.membership.findUnique({
        where: { originalTransactionId },
      });
      if (existingMembership && existingMembership.userId !== req.uid) {
        console.warn('[iap/verify-apple] Receipt replay attempt, uid:', req.uid, 'originalTxId:', originalTransactionId);
        res.status(400).json({ error: 'Receipt already used by another account' }); return;
      }
    }

    // Atomic update: Membership + Profile in one transaction to prevent desync
    await prisma.$transaction([
      prisma.membership.upsert({
        where: { userId: req.uid },
        update: { platform: 'ios', productId, active, expiry, environment, originalTransactionId, updatedAt: new Date() },
        create: { userId: req.uid, platform: 'ios', productId, active, expiry, environment, originalTransactionId },
      }),
      prisma.profile.update({
        where: { userId: req.uid },
        data: { isPremium: active },
      }),
    ]);

    res.json({ success: true, active, expiry });
  } catch (err) {
    console.error('[iap/verify-apple]', err);
    res.status(500).json({ error: 'Apple verification failed' });
  }
});

// POST /iap/verify-android
router.post('/verify-android', async (req: Request, res: Response) => {
  try {
    const { purchaseToken, productId, subscriptionId } = req.body;
    if (!purchaseToken || !productId) {
      res.status(400).json({ error: 'purchaseToken and productId required' }); return;
    }

    const serviceAccountRaw = process.env.PLAY_SERVICE_ACCOUNT_JSON;
    const packageName = process.env.PLAY_BILLING_PACKAGE_NAME;

    if (!serviceAccountRaw || !packageName) {
      console.error('[iap/verify-android] PLAY_SERVICE_ACCOUNT_JSON or PLAY_BILLING_PACKAGE_NAME not set');
      res.status(500).json({ error: 'Payment configuration error' }); return;
    }

    let serviceAccountJson: any;
    try {
      serviceAccountJson = JSON.parse(serviceAccountRaw);
    } catch {
      console.error('[iap/verify-android] PLAY_SERVICE_ACCOUNT_JSON is not valid JSON');
      res.status(500).json({ error: 'Payment configuration error' }); return;
    }

    const auth = new google.auth.GoogleAuth({
      credentials: serviceAccountJson,
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    const androidpublisher = google.androidpublisher({ version: 'v3', auth });

    const response = await androidpublisher.purchases.subscriptions.get({
      packageName,
      subscriptionId: subscriptionId ?? productId,
      token: purchaseToken,
    });

    const sub = response.data;
    const expiry = sub.expiryTimeMillis ? new Date(parseInt(sub.expiryTimeMillis)) : null;
    const active = expiry ? expiry > new Date() : false;

    // Acknowledge if not yet acknowledged (required within 3 days or Google refunds)
    if (sub.acknowledgementState === 0) {
      await androidpublisher.purchases.subscriptions.acknowledge({
        packageName,
        subscriptionId: subscriptionId ?? productId,
        token: purchaseToken,
        requestBody: {},
      });
    }

    // SECURITY: Prevent receipt replay — purchaseToken must belong to this user only
    const existingAndroidMembership = await prisma.membership.findUnique({
      where: { originalTransactionId: purchaseToken },
    });
    if (existingAndroidMembership && existingAndroidMembership.userId !== req.uid) {
      console.warn('[iap/verify-android] Receipt replay attempt, uid:', req.uid, 'token:', purchaseToken.slice(0, 20));
      res.status(400).json({ error: 'Purchase token already used by another account' }); return;
    }

    // Atomic update: Membership + Profile in one transaction to prevent desync
    await prisma.$transaction([
      prisma.membership.upsert({
        where: { userId: req.uid },
        update: { platform: 'android', productId, active, expiry, environment: 'production', originalTransactionId: purchaseToken, updatedAt: new Date() },
        create: { userId: req.uid, platform: 'android', productId, active, expiry, environment: 'production', originalTransactionId: purchaseToken },
      }),
      prisma.profile.update({
        where: { userId: req.uid },
        data: { isPremium: active },
      }),
    ]);

    res.json({ success: true, active, expiry });
  } catch (err) {
    console.error('[iap/verify-android]', err);
    res.status(500).json({ error: 'Android verification failed' });
  }
});

export default router;
