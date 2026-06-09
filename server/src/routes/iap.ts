import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { prisma } from '../db/client';
import { google } from 'googleapis';
import fs from 'fs';
import {
  AppStoreServerAPIClient,
  Environment,
  ReceiptUtility,
  Status,
} from 'app-store-server-library';

const router = Router();
router.use(requireAuth);

// ── Apple App Store Server API config ───────────────────────────────────────
// Modern verification (replaces the deprecated /verifyReceipt + shared secret).
// Uses the in-app-purchase .p8 key + Key ID + Issuer ID.
const APPLE_KEY_ID = process.env.APPLE_KEY_ID;
const APPLE_ISSUER_ID = process.env.APPLE_ISSUER_ID;
const APPLE_BUNDLE_ID = process.env.APPLE_BUNDLE_ID;
const APPLE_PRIVATE_KEY_PATH = process.env.APPLE_PRIVATE_KEY_PATH;

function loadApplePrivateKey(): string | null {
  if (process.env.APPLE_PRIVATE_KEY) {
    return process.env.APPLE_PRIVATE_KEY.replace(/\\n/g, '\n');
  }
  if (APPLE_PRIVATE_KEY_PATH && fs.existsSync(APPLE_PRIVATE_KEY_PATH)) {
    return fs.readFileSync(APPLE_PRIVATE_KEY_PATH, 'utf8');
  }
  return null;
}

// Decode a JWS payload (the middle segment) WITHOUT signature re-verification.
// Safe here because the JWS came directly from Apple's App Store Server API over
// an authenticated TLS connection (our request is signed with the .p8 key).
function decodeJwsPayload(jws: string | undefined): any {
  if (!jws) return {};
  const parts = jws.split('.');
  if (parts.length < 2) return {};
  try {
    return JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
  } catch {
    return {};
  }
}

// POST /iap/verify-apple
router.post('/verify-apple', async (req: Request, res: Response) => {
  try {
    const { receiptData, productId } = req.body;
    if (!receiptData || !productId) {
      res.status(400).json({ error: 'receiptData and productId required' }); return;
    }

    const signingKey = loadApplePrivateKey();
    if (!signingKey || !APPLE_KEY_ID || !APPLE_ISSUER_ID || !APPLE_BUNDLE_ID) {
      console.error('[iap/verify-apple] App Store Server API not configured (need APPLE_PRIVATE_KEY[_PATH], APPLE_KEY_ID, APPLE_ISSUER_ID, APPLE_BUNDLE_ID)');
      res.status(500).json({ error: 'Payment configuration error' }); return;
    }

    // 1. Extract a transaction id from the receipt the client already sends.
    const transactionId = new ReceiptUtility().extractTransactionIdFromAppReceipt(receiptData);
    if (!transactionId) {
      console.warn('[iap/verify-apple] no transactionId in receipt, uid:', req.uid);
      res.status(400).json({ error: 'Invalid receipt' }); return;
    }

    // 2. Query subscription status. Apple review uses Sandbox, real users use
    //    Production, and a transaction only resolves in its own environment —
    //    so try Production first, then fall back to Sandbox.
    let statusResponse: any = null;
    let usedEnv: Environment = Environment.PRODUCTION;
    let lastErr: unknown = null;
    for (const env of [Environment.PRODUCTION, Environment.SANDBOX]) {
      try {
        const client = new AppStoreServerAPIClient(
          signingKey, APPLE_KEY_ID, APPLE_ISSUER_ID, APPLE_BUNDLE_ID, env,
        );
        statusResponse = await client.getAllSubscriptionStatuses(transactionId);
        usedEnv = env;
        lastErr = null;
        break;
      } catch (e) {
        lastErr = e;
        // Not found in this environment (or env mismatch) → try the next one.
      }
    }
    if (!statusResponse) {
      console.warn('[iap/verify-apple] status lookup failed both envs, uid:', req.uid, 'err:', (lastErr as any)?.message);
      res.status(400).json({ error: 'Invalid receipt' }); return;
    }

    // 3. Pick the latest transaction matching the purchased productId.
    let best: { status: number; info: any } | null = null;
    const considerProductMatch = (wantMatch: boolean) => {
      for (const group of (statusResponse.data ?? [])) {
        for (const lt of (group.lastTransactions ?? [])) {
          const info = decodeJwsPayload(lt.signedTransactionInfo);
          if (wantMatch && info.productId !== productId) continue;
          if (!best || (info.expiresDate ?? 0) > (best.info.expiresDate ?? 0)) {
            best = { status: lt.status, info };
          }
        }
      }
    };
    considerProductMatch(true);
    if (!best) considerProductMatch(false); // fallback: any subscription in the group

    let active = false;
    let expiry: Date | null = null;
    let originalTransactionId: string | undefined;
    let resolvedProductId = productId;

    if (best) {
      const chosen: { status: number; info: any } = best;
      expiry = chosen.info.expiresDate ? new Date(chosen.info.expiresDate) : null;
      originalTransactionId = chosen.info.originalTransactionId;
      resolvedProductId = chosen.info.productId ?? productId;
      // ACTIVE (1) or BILLING_GRACE_PERIOD (4) grant entitlement.
      const entitledStatus = chosen.status === Status.ACTIVE || chosen.status === Status.BILLING_GRACE_PERIOD;
      active = entitledStatus && (!expiry || expiry > new Date());
    }

    const environment = usedEnv === Environment.SANDBOX ? 'sandbox' : 'production';

    // SECURITY: prevent receipt replay — a given originalTransactionId may only
    // belong to one account.
    if (originalTransactionId) {
      const existing = await prisma.membership.findUnique({ where: { originalTransactionId } });
      if (existing && existing.userId !== req.uid) {
        console.warn('[iap/verify-apple] replay attempt, uid:', req.uid, 'origTxId:', originalTransactionId);
        res.status(400).json({ error: 'Receipt already used by another account' }); return;
      }
    }

    // Atomic: Membership + Profile in one transaction to prevent desync.
    await prisma.$transaction([
      prisma.membership.upsert({
        where: { userId: req.uid },
        update: { platform: 'ios', productId: resolvedProductId, active, expiry, environment, originalTransactionId, updatedAt: new Date() },
        create: { userId: req.uid, platform: 'ios', productId: resolvedProductId, active, expiry, environment, originalTransactionId },
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
