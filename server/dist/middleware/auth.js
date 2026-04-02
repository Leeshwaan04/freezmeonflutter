"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requireAuth = requireAuth;
const jwt_1 = require("../services/jwt");
function requireAuth(req, res, next) {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing or invalid Authorization header' });
        return;
    }
    const token = authHeader.slice(7);
    try {
        const payload = (0, jwt_1.verifyAccessToken)(token);
        req.uid = payload.uid;
        req.jwtPayload = payload;
        next();
    }
    catch {
        res.status(401).json({ error: 'Invalid or expired token' });
    }
}
//# sourceMappingURL=auth.js.map