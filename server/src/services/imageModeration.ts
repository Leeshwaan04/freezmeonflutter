/**
 * AI Image Moderation Service
 *
 * Uses AWS Rekognition to detect NSFW / explicit content in uploaded images.
 * If Rekognition is not configured (no AWS credentials), moderation is skipped
 * gracefully — this allows local development without AWS.
 *
 * Configuration:
 *   - AWS_REGION (env) — defaults to eu-north-1
 *   - IMAGE_MODERATION_ENABLED (env) — set to 'true' to enable (default: true in prod)
 *   - IMAGE_MODERATION_THRESHOLD (env) — confidence threshold 0-100 (default: 80)
 */

import {
  RekognitionClient,
  DetectModerationLabelsCommand,
} from '@aws-sdk/client-rekognition';
import { logger } from './logger';

const MODERATION_ENABLED =
  (process.env.IMAGE_MODERATION_ENABLED ?? 'true').toLowerCase() === 'true';

const CONFIDENCE_THRESHOLD = parseInt(
  process.env.IMAGE_MODERATION_THRESHOLD ?? '80',
  10,
);

// Categories that trigger an immediate rejection
const BLOCKED_CATEGORIES = new Set([
  'Explicit Nudity',
  'Non-Explicit Nudity of Intimate parts and Coverage',
  'Violence',
  'Visually Disturbing',
  'Drugs & Tobacco',
  'Hate Symbols',
]);

let rekognition: RekognitionClient | null = null;

try {
  if (MODERATION_ENABLED) {
    rekognition = new RekognitionClient({
      region: process.env.AWS_REGION ?? 'eu-north-1',
    });
  }
} catch (err) {
  logger.warn({ msg: 'rekognition_init_failed', err });
}

export interface ModerationResult {
  safe: boolean;
  reason?: string;
  labels: Array<{ name: string; confidence: number; parentName?: string }>;
}

/**
 * Moderate an image stored in S3.
 *
 * @param bucket - S3 bucket name
 * @param key    - S3 object key
 * @returns ModerationResult — `safe: true` if the image passes, `safe: false` with reason if blocked
 */
export async function moderateImage(
  bucket: string,
  key: string,
): Promise<ModerationResult> {
  if (!MODERATION_ENABLED || !rekognition) {
    logger.info({ msg: 'moderation_skipped', reason: 'disabled_or_no_client', key });
    return { safe: true, labels: [] };
  }

  try {
    const command = new DetectModerationLabelsCommand({
      Image: {
        S3Object: {
          Bucket: bucket,
          Name: key,
        },
      },
      MinConfidence: CONFIDENCE_THRESHOLD,
    });

    const response = await rekognition.send(command);
    const labels = (response.ModerationLabels ?? []).map((l) => ({
      name: l.Name ?? 'Unknown',
      confidence: l.Confidence ?? 0,
      parentName: l.ParentName ?? undefined,
    }));

    // Check if any blocked category was detected above threshold
    const blockedLabel = labels.find(
      (l) =>
        BLOCKED_CATEGORIES.has(l.name) ||
        (l.parentName && BLOCKED_CATEGORIES.has(l.parentName)),
    );

    if (blockedLabel) {
      logger.warn({
        msg: 'moderation_blocked',
        key,
        label: blockedLabel.name,
        confidence: blockedLabel.confidence,
        parent: blockedLabel.parentName,
      });
      return {
        safe: false,
        reason: `Content flagged: ${blockedLabel.name} (${blockedLabel.confidence.toFixed(1)}% confidence)`,
        labels,
      };
    }

    logger.info({ msg: 'moderation_passed', key, labelCount: labels.length });
    return { safe: true, labels };
  } catch (err) {
    // If Rekognition fails (quota, permissions, network), allow the image
    // through rather than blocking all uploads. Log for investigation.
    logger.error({ msg: 'moderation_error', key, err });
    return { safe: true, labels: [] };
  }
}
