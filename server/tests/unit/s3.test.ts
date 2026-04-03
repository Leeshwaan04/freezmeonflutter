// Unit tests for S3 service — mock the AWS SDK so no real S3 calls are made

jest.mock('@aws-sdk/client-s3', () => ({
  S3Client: jest.fn().mockImplementation(() => ({})),
  PutObjectCommand: jest.fn().mockImplementation((input) => ({ input })),
  DeleteObjectCommand: jest.fn().mockImplementation((input) => ({ input })),
}));

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn().mockResolvedValue(
    'https://freezme-user-uploads.s3.eu-north-1.amazonaws.com/uploads/uid/file.jpg?X-Amz-Signature=mocked'
  ),
}));

import { getPresignedUploadUrl } from '../../src/services/s3';

describe('S3 Service — Unit Tests', () => {

  beforeEach(() => {
    process.env.S3_BUCKET_NAME     = 'freezme-user-uploads';
    process.env.S3_PUBLIC_BASE_URL = 'https://freezme-user-uploads.s3.eu-north-1.amazonaws.com';
    process.env.AWS_REGION         = 'eu-north-1';
  });

  describe('getPresignedUploadUrl', () => {
    it('returns uploadUrl, publicUrl and key', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      expect(result).toHaveProperty('uploadUrl');
      expect(result).toHaveProperty('publicUrl');
      expect(result).toHaveProperty('key');
    });

    it('uploadUrl contains S3 domain', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      expect(result.uploadUrl).toContain('s3');
    });

    it('key is scoped to uid', async () => {
      const result = await getPresignedUploadUrl('uid-abc', 'avatar.png', 'image/png');
      expect(result.key).toContain('uid-abc');
    });

    it('key contains uploads/ prefix', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      expect(result.key.startsWith('uploads/')).toBe(true);
    });

    it('preserves file extension from filename', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'photo.png', 'image/png');
      expect(result.key.endsWith('.png')).toBe(true);
    });

    it('publicUrl uses public base URL', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      expect(result.publicUrl.startsWith('https://freezme-user-uploads.s3.eu-north-1.amazonaws.com')).toBe(true);
    });

    it('publicUrl contains the key', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      expect(result.publicUrl).toContain(result.key);
    });

    it('two calls produce different keys (UUID)', async () => {
      const r1 = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      const r2 = await getPresignedUploadUrl('uid-123', 'photo.jpg', 'image/jpeg');
      expect(r1.key).not.toBe(r2.key);
    });

    it('handles filename without extension gracefully', async () => {
      const result = await getPresignedUploadUrl('uid-123', 'noextfile', 'image/jpeg');
      expect(result.key).toContain('uid-123');
    });
  });
});
