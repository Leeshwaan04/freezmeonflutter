"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const express_1 = require("express");
const auth_1 = require("../middleware/auth");
const s3_1 = require("../services/s3");
const router = (0, express_1.Router)();
router.use(auth_1.requireAuth);
// GET /storage/upload-url — get presigned S3 URL for direct upload
router.get('/upload-url', async (req, res) => {
    try {
        const { filename, contentType } = req.query;
        if (!filename || !contentType) {
            res.status(400).json({ error: 'filename and contentType required' });
            return;
        }
        if (!contentType.startsWith('image/')) {
            res.status(400).json({ error: 'Only image uploads are allowed' });
            return;
        }
        const result = await (0, s3_1.getPresignedUploadUrl)(req.uid, filename, contentType);
        res.json(result);
    }
    catch (err) {
        console.error('[storage/upload-url]', err);
        res.status(500).json({ error: 'Failed to generate upload URL' });
    }
});
exports.default = router;
//# sourceMappingURL=storage.js.map