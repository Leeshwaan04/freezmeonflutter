export declare function getPresignedUploadUrl(uid: string, originalFilename: string, contentType: string): Promise<{
    uploadUrl: string;
    publicUrl: string;
    key: string;
}>;
export declare function deleteS3Object(key: string): Promise<void>;
//# sourceMappingURL=s3.d.ts.map