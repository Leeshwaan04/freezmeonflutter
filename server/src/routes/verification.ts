import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { getPresignedUploadUrl } from '../services/s3';
import { prisma } from '../db/client';

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
    console.error('[verification/selfie-url]', err);
    res.status(500).json({ error: 'Failed to generate selfie upload URL' });
  }
});

// POST /verification/selfie-submit — record selfie key, mark verification pending
router.post('/selfie-submit', async (req: Request, res: Response) => {
  try {
    const { selfieKey } = req.body;
    if (!selfieKey) { res.status(400).json({ error: 'selfieKey required' }); return; }

    // Store selfie key in user record for async review
    await prisma.user.update({
      where: { id: req.uid },
      data: { status: 'verification_pending' },
    });

    res.json({ success: true, status: 'pending' });
  } catch (err) {
    console.error('[verification/selfie-submit]', err);
    res.status(500).json({ error: 'Failed to record verification' });
  }
});

// GET /verification/status — check verification status
router.get('/status', async (req: Request, res: Response) => {
  try {
    const user = await prisma.user.findUnique({ where: { id: req.uid }, select: { status: true } });
    res.json({ status: user?.status ?? 'unverified' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch verification status' });
  }
});

export default router;
