import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { getPresignedUploadUrl } from '../services/s3';
import { prisma } from '../db/client';
import { logger } from '../services/logger';

const router = Router();
router.use(requireAuth);

// POST /verification/selfie-url — generate presigned S3 URL for selfie upload
router.post('/selfie-url', async (req: Request, res: Response) => {
  try {
    const result = await getPresignedUploadUrl(
      req.uid,
      `selfie_${req.uid}.jpg`,
      'image/jpeg'
    );
    // Return selfieKey so client can submit it back after upload
    res.json({
      uploadUrl: result.uploadUrl,
      publicUrl: result.publicUrl,
      selfieKey: result.key,
    });
  } catch (err) {
    logger.error({ msg: 'verification_selfie_url_error', err });
    res.status(500).json({ error: 'Failed to generate selfie upload URL' });
  }
});

// Validates that a selfie key belongs to the requesting user's upload prefix.
function ownsSelfieKey(uid: string, key: string): boolean {
  // Keys are minted by getPresignedUploadUrl as `uploads/<uid>/...`
  return typeof key === 'string' && key.startsWith(`uploads/${uid}/`);
}

// POST /verification/selfie-submit — record selfie key and verify the user.
// AUTO_APPROVE_VERIFICATION=false enables a manual review queue (status stays
// `verification_pending` until an admin flips it). Default true for v1 since
// there is no moderation dashboard yet.
router.post('/selfie-submit', async (req: Request, res: Response) => {
  try {
    const { selfieKey } = req.body;
    if (!selfieKey) { res.status(400).json({ error: 'selfieKey required' }); return; }
    if (!ownsSelfieKey(req.uid, selfieKey)) {
      res.status(403).json({ error: 'Selfie key does not belong to you' }); return;
    }

    // Reject duplicate submissions while one is already pending review
    const current = await prisma.user.findUnique({ where: { id: req.uid }, select: { status: true } });
    if (current?.status === 'verification_pending') {
      res.json({ success: true, status: 'pending' }); return;
    }

    const autoApprove = process.env.AUTO_APPROVE_VERIFICATION !== 'false';

    if (autoApprove) {
      await prisma.$transaction([
        prisma.user.update({ where: { id: req.uid }, data: { selfieKey, status: 'verified' } }),
        prisma.profile.update({ where: { userId: req.uid }, data: { isVerified: true } }),
      ]);
      res.json({ success: true, status: 'verified' });
    } else {
      await prisma.user.update({
        where: { id: req.uid },
        data: { selfieKey, status: 'verification_pending' },
      });
      res.json({ success: true, status: 'pending' });
    }
  } catch (err) {
    logger.error({ msg: 'verification_selfie_submit_error', err });
    res.status(500).json({ error: 'Failed to record verification' });
  }
});

// GET /verification/status — check verification status
router.get('/status', async (req: Request, res: Response) => {
  try {
    const [user, profile] = await Promise.all([
      prisma.user.findUnique({ where: { id: req.uid }, select: { status: true } }),
      prisma.profile.findUnique({ where: { userId: req.uid }, select: { isVerified: true } }),
    ]);
    res.json({
      status: user?.status ?? 'unverified',
      isVerified: profile?.isVerified ?? false,
    });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch verification status' });
  }
});

export default router;
