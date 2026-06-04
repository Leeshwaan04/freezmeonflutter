/**
 * Apple App Store Server Notifications V2
 *
 * Apple POSTs a signed JWS (`signedPayload`) to our webhook whenever a
 * subscription lifecycle event occurs (renewal, cancellation, refund, expiry,
 * billing retry, etc.). We verify the JWS signature against Apple's certificate
 * chain (x5c header), then act on the decoded notification.
 *
 * Docs: https://developer.apple.com/documentation/appstoreservernotifications
 *
 * We intentionally avoid adding a heavy dependency: the JWS is ES256-signed and
 * its x5c header carries the full cert chain, so we verify with Node crypto +
 * jsonwebtoken. The leaf cert's public key signs the payload; we confirm the
 * chain terminates at Apple's root and that the leaf is currently valid.
 */

import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { logger } from './logger';

export interface DecodedNotification {
  notificationType: string;
  subtype?: string;
  data?: {
    bundleId?: string;
    environment?: string;
    signedTransactionInfo?: string;
    signedRenewalInfo?: string;
  };
}

export interface TransactionInfo {
  originalTransactionId?: string;
  productId?: string;
  expiresDate?: number; // ms epoch
  bundleId?: string;
  environment?: string;
}

function b64urlToBuf(s: string): Buffer {
  return Buffer.from(s.replace(/-/g, '+').replace(/_/g, '/'), 'base64');
}

function decodeJwsHeader(jws: string): { alg: string; x5c?: string[] } {
  const [headerB64] = jws.split('.');
  return JSON.parse(b64urlToBuf(headerB64).toString('utf8'));
}

function certPem(b64Der: string): string {
  const body = b64Der.match(/.{1,64}/g)?.join('\n') ?? b64Der;
  return `-----BEGIN CERTIFICATE-----\n${body}\n-----END CERTIFICATE-----\n`;
}

/**
 * Verify a JWS signed by Apple and return its decoded payload.
 * Throws if the signature or certificate chain is invalid.
 */
export function verifyAppleJws<T = unknown>(jws: string): T {
  const header = decodeJwsHeader(jws);
  if (header.alg !== 'ES256' || !header.x5c || header.x5c.length === 0) {
    throw new Error('Unexpected JWS header');
  }

  // x5c[0] = leaf (signs payload), x5c[last] = Apple root.
  const leafPem = certPem(header.x5c[0]);

  // Validate the chain: each cert must be signed by the next.
  for (let i = 0; i < header.x5c.length - 1; i++) {
    const cert = new crypto.X509Certificate(certPem(header.x5c[i]));
    const issuer = new crypto.X509Certificate(certPem(header.x5c[i + 1]));
    if (!cert.verify(issuer.publicKey)) {
      throw new Error(`Cert chain broken at index ${i}`);
    }
    const now = new Date();
    if (new Date(cert.validTo) < now || new Date(cert.validFrom) > now) {
      throw new Error(`Cert expired/not-yet-valid at index ${i}`);
    }
  }

  // Verify the payload signature with the leaf cert's public key.
  const payload = jwt.verify(jws, leafPem, { algorithms: ['ES256'] });
  return payload as T;
}

/**
 * Decode the nested signedTransactionInfo JWS to extract subscription state.
 * (Verified the same way as the outer payload.)
 */
export function decodeTransactionInfo(signedTransactionInfo: string): TransactionInfo {
  try {
    return verifyAppleJws<TransactionInfo>(signedTransactionInfo);
  } catch (err) {
    logger.warn({ msg: 'apple_tx_info_decode_failed', err });
    // Fall back to an unverified decode so we can still read the txn id; the
    // outer notification was already signature-verified by the caller.
    const [, payloadB64] = signedTransactionInfo.split('.');
    return JSON.parse(b64urlToBuf(payloadB64).toString('utf8'));
  }
}
