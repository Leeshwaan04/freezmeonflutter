import { Router, Request, Response } from 'express';
import { prisma } from '../db/client';
import { logger } from '../services/logger';
import {
  verifyAppleJws,
  decodeTransactionInfo,
  DecodedNotification,
} from '../services/apple-notifications';

const router = Router();

// POST /webhooks/apple — App Store Server Notifications V2 (UNAUTHENTICATED;
// secured by Apple's JWS signature, not our JWT). Apple expects a 200 quickly;
// any non-2xx triggers retries.
router.post('/apple', async (req: Request, res: Response) => {
  try {
    const signedPayload = req.body?.signedPayload;
    if (!signedPayload || typeof signedPayload !== 'string') {
      res.status(400).json({ error: 'signedPayload required' });
      return;
    }

    let notification: DecodedNotification;
    try {
      notification = verifyAppleJws<DecodedNotification>(signedPayload);
    } catch (err) {
      logger.warn({ msg: 'apple_webhook_bad_signature', err });
      res.status(401).json({ error: 'Invalid signature' });
      return;
    }

    // Validate bundle id matches our app.
    const expectedBundleId = process.env.APPLE_BUNDLE_ID;
    const bundleId = notification.data?.bundleId;
    if (expectedBundleId && bundleId && bundleId !== expectedBundleId) {
      logger.warn({ msg: 'apple_webhook_bundle_mismatch', bundleId });
      res.status(200).json({ ok: true }); // ack to stop retries; just ignore
      return;
    }

    const { notificationType, subtype } = notification;
    const signedTx = notification.data?.signedTransactionInfo;
    const tx = signedTx ? decodeTransactionInfo(signedTx) : null;
    const originalTransactionId = tx?.originalTransactionId;

    if (!originalTransactionId) {
      logger.info({ msg: 'apple_webhook_no_txn', notificationType });
      res.status(200).json({ ok: true });
      return;
    }

    const membership = await prisma.membership.findUnique({
      where: { originalTransactionId },
    });
    if (!membership) {
      // We may receive notifications for transactions not yet recorded (the
      // client verify call may arrive after). Ack and let the sweep/verify path
      // reconcile later.
      logger.info({ msg: 'apple_webhook_membership_unknown', notificationType, originalTransactionId });
      res.status(200).json({ ok: true });
      return;
    }

    // Decide the resulting active state from the notification type.
    // https://developer.apple.com/documentation/appstoreservernotifications/notificationtype
    const REVOKE = new Set(['EXPIRED', 'REFUND', 'REVOKE', 'GRACE_PERIOD_EXPIRED']);
    const GRANT = new Set(['SUBSCRIBED', 'DID_RENEW', 'OFFER_REDEEMED', 'DID_RECOVER']);

    const expiry = tx?.expiresDate ? new Date(tx.expiresDate) : membership.expiry;
    let active = membership.active;
    if (REVOKE.has(notificationType)) active = false;
    else if (GRANT.has(notificationType)) active = expiry ? expiry > new Date() : true;
    else if (notificationType === 'DID_CHANGE_RENEWAL_STATUS') {
      // auto-renew toggled — does not change current entitlement; expiry governs.
      active = expiry ? expiry > new Date() : membership.active;
    }

    await prisma.$transaction([
      prisma.membership.update({
        where: { originalTransactionId },
        data: { active, expiry: expiry ?? undefined, productId: tx?.productId ?? membership.productId },
      }),
      prisma.profile.update({
        where: { userId: membership.userId },
        data: { isPremium: active },
      }),
    ]);

    logger.info({ msg: 'apple_webhook_processed', notificationType, subtype, active, userId: membership.userId });
    res.status(200).json({ ok: true });
  } catch (err) {
    logger.error({ msg: 'apple_webhook_error', err });
    // Return 200 so Apple doesn't hammer retries on our internal errors; the
    // hourly expire_subscriptions sweep is the safety net.
    res.status(200).json({ ok: true });
  }
});

export default router;
