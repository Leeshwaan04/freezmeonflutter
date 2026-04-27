import { Router, Request, Response } from 'express';
import { S3Client, GetObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { requireAuth } from '../middleware/auth';
import { getPresignedUploadUrl } from '../services/s3';
import { logger } from '../services/logger';

const router = Router();
router.use(requireAuth);

const ALLOWED_IMAGE_TYPES = new Set(['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/heic']);
const MAX_FILE_SIZE_BYTES = 8 * 1024 * 1024; // 8 MB — must match client-side check

const s3 = new S3Client({
  region: process.env.AWS_REGION ?? 'eu-north-1',
});
const BUCKET = process.env.S3_BUCKET_NAME!;
const CDN_BASE = process.env.S3_PUBLIC_BASE_URL!;

// Magic byte signatures for accepted image types
const MAGIC_SIGNATURES = [
  { type: 'jpeg', bytes: [0xFF, 0xD8, 0xFF] },
  { type: 'png',  bytes: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] },
  { type: 'webp', bytes: [0x52, 0x49, 0x46, 0x46] }, // RIFF.... with WEBP at offset 8
  { type: 'heic', bytes: [] },  // HEIC has complex ftyp box — we skip deep check for now
];

function detectMagicBytes(buf: Buffer): boolean {
  // JPEG: FF D8 FF
  if (buf[0] === 0xFF && buf[1] === 0xD8 && buf[2] === 0xFF) return true;
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4E && buf[3] === 0x47) return true;
  // WebP: RIFF????WEBP
  if (
    buf[0] === 0x52 && buf[1] === 0x49 && buf[2] === 0x46 && buf[3] === 0x46 &&
    buf[8] === 0x57 && buf[9] === 0x45 && buf[10] === 0x42 && buf[11] === 0x50
  ) return true;
  // HEIC/HEIF: ftyp box at byte 4 with heic/heif/mif1 brand
  if (buf.length >= 12) {
    const brand = buf.slice(4, 8).toString('ascii');
    if (['ftyp', 'mif1'].some(b => buf.slice(4, 8).toString('ascii') === b)) return true;
    if (['heic', 'heif', 'mif1', 'msf1'].includes(buf.slice(8, 12).toString('ascii'))) return true;
  }
  return false;
}

// GET /storage/upload-url — get presigned S3 URL for direct client upload
router.get('/upload-url', async (req: Request, res: Response) => {
  try {
    const { filename, contentType, fileSize } = req.query as {
      filename?: string; contentType?: string; fileSize?: string;
    };

    if (!filename || !contentType) {
      res.status(400).json({ error: 'filename and contentType required' }); return;
    }

    if (!ALLOWED_IMAGE_TYPES.has(contentType.toLowerCase())) {
      res.status(400).json({ error: 'Unsupported image type. Use JPEG, PNG, WebP, or HEIC.' }); return;
    }

    // Validate declared file size if provided — prevents obviously oversized uploads
    if (fileSize !== undefined) {
      const size = parseInt(fileSize, 10);
      if (isNaN(size) || size <= 0 || size > MAX_FILE_SIZE_BYTES) {
        res.status(400).json({ error: `File too large. Maximum size is ${MAX_FILE_SIZE_BYTES / (1024 * 1024)} MB.` }); return;
      }
    }

    const result = await getPresignedUploadUrl(req.uid, filename, contentType);
    res.json(result);
  } catch (err) {
    logger.error({ msg: 'storage_upload_url_error', err });
    res.status(500).json({ error: 'Failed to generate upload URL' });
  }
});

/**
 * POST /storage/confirm
 * After the client uploads directly to S3, call this to validate the file.
 * We fetch the first 16 bytes from S3 and check magic bytes.
 * Only files from the requesting user's upload path are accepted.
 *
 * Body: { key: string }
 * Response: { cdnUrl: string } on success, 400 on bad file, 403 on ownership fail.
 */
router.post('/confirm', async (req: Request, res: Response) => {
  try {
    const { key } = req.body as { key?: string };
    if (!key || typeof key !== 'string') {
      res.status(400).json({ error: 'key required' }); return;
    }

    // Ownership check — key must start with uploads/<uid>/
    const expectedPrefix = `uploads/${req.uid}/`;
    if (!key.startsWith(expectedPrefix)) {
      logger.warn({ msg: 'storage_confirm_ownership_fail', uid: req.uid, key });
      res.status(403).json({ error: 'Forbidden' }); return;
    }

    // Path traversal guard
    if (key.includes('..') || key.includes('//')) {
      res.status(400).json({ error: 'Invalid key' }); return;
    }

    // Fetch just the first 16 bytes from S3 to check magic bytes
    let headBuf: Buffer;
    try {
      const cmd = new GetObjectCommand({ Bucket: BUCKET, Key: key, Range: 'bytes=0-15' });
      const obj = await s3.send(cmd);
      const chunks: Buffer[] = [];
      for await (const chunk of obj.Body as AsyncIterable<Uint8Array>) {
        chunks.push(Buffer.from(chunk));
      }
      headBuf = Buffer.concat(chunks);
    } catch (fetchErr) {
      logger.error({ msg: 'storage_confirm_s3_fetch_fail', key, err: fetchErr });
      res.status(400).json({ error: 'Could not retrieve uploaded file. Did the upload complete?' }); return;
    }

    // Magic byte validation — polyglot file rejection
    if (!detectMagicBytes(headBuf)) {
      // Delete the rejected file from S3
      try {
        await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
      } catch (_) { /* best effort */ }
      logger.warn({ msg: 'storage_confirm_magic_fail', uid: req.uid, key, bytes: headBuf.toString('hex') });
      res.status(400).json({ error: 'Unsupported or corrupt image file.' }); return;
    }

    // Enforce CDN URL — never return raw S3 URL to clients
    if (!CDN_BASE) {
      res.status(500).json({ error: 'CDN not configured' }); return;
    }
    const cdnUrl = `${CDN_BASE}/${key}`;

    logger.info({ msg: 'storage_confirm_ok', uid: req.uid, key });
    res.json({ cdnUrl });
  } catch (err) {
    logger.error({ msg: 'storage_confirm_error', err });
    res.status(500).json({ error: 'confirm_failed' });
  }
});

export default router;
