"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPresignedUploadUrl = getPresignedUploadUrl;
exports.deleteS3Object = deleteS3Object;
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const uuid_1 = require("uuid");
const s3 = new client_s3_1.S3Client({
    region: process.env.AWS_REGION ?? 'us-east-1',
    credentials: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    },
});
const BUCKET = process.env.S3_BUCKET_NAME;
const PUBLIC_BASE = process.env.S3_PUBLIC_BASE_URL;
async function getPresignedUploadUrl(uid, originalFilename, contentType) {
    const ext = originalFilename.split('.').pop() ?? 'jpg';
    const key = `uploads/${uid}/${(0, uuid_1.v4)()}.${ext}`;
    const command = new client_s3_1.PutObjectCommand({
        Bucket: BUCKET,
        Key: key,
        ContentType: contentType,
        CacheControl: 'max-age=31536000',
    });
    const uploadUrl = await (0, s3_request_presigner_1.getSignedUrl)(s3, command, { expiresIn: 300 });
    const publicUrl = `${PUBLIC_BASE}/${key}`;
    return { uploadUrl, publicUrl, key };
}
async function deleteS3Object(key) {
    await s3.send(new client_s3_1.DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
}
//# sourceMappingURL=s3.js.map