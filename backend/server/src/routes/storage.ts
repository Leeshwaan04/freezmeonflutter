import { Router, Request, Response } from 'express';
import { requireAuth } from '../middleware/auth';
import { getPresignedUploadUrl } from '../services/s3';

const router = Router();
router.use(requireAuth);

// GET /storage/upload-url — get presigned S3 URL for direct upload
router.get('/upload-url', async (req: Request, res: Response) => {
  try {
    const { filename, contentType } = req.query as { filename?: string; contentType?: string };
    if (!filename || !contentType) {
      res.status(400).json({ error: 'filename and contentType required' }); return;
    }

    if (!contentType.startsWith('image/')) {
      res.status(400).json({ error: 'Only image uploads are allowed' }); return;
    }

    const result = await getPresignedUploadUrl(req.uid, filename, contentType);
    res.json(result);
  } catch (err) {
    console.error('[storage/upload-url]', err);
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

export default router;
