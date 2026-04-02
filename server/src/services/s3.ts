import { S3Client, PutObjectCommand, DeleteObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v4 as uuidv4 } from 'uuid';

const s3 = new S3Client({
  region: process.env.AWS_REGION ?? 'us-east-1',
  credentials: {
    accessKeyId: process.env.AWS_ACCESS_KEY_ID!,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY!,
  },
});

const BUCKET = process.env.S3_BUCKET_NAME!;
const PUBLIC_BASE = process.env.S3_PUBLIC_BASE_URL!;

export async function getPresignedUploadUrl(
  uid: string,
  originalFilename: string,
  contentType: string
): Promise<{ uploadUrl: string; publicUrl: string; key: string }> {
  const ext = originalFilename.split('.').pop() ?? 'jpg';
  const key = `uploads/${uid}/${uuidv4()}.${ext}`;

  const command = new PutObjectCommand({
    Bucket: BUCKET,
    Key: key,
    ContentType: contentType,
    CacheControl: 'max-age=31536000',
  });

  const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 });
  const publicUrl = `${PUBLIC_BASE}/${key}`;

  return { uploadUrl, publicUrl, key };
}

export async function deleteS3Object(key: string): Promise<void> {
  await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
}
