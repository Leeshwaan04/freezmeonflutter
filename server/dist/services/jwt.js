"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.signAccessToken = signAccessToken;
exports.signRefreshToken = signRefreshToken;
exports.verifyAccessToken = verifyAccessToken;
exports.verifyRefreshToken = verifyRefreshToken;
exports.issueTokenPair = issueTokenPair;
exports.revokeRefreshToken = revokeRefreshToken;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const client_1 = require("../db/client");
const JWT_SECRET = process.env.JWT_SECRET;
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET;
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN ?? '15m';
const JWT_REFRESH_EXPIRES_IN = process.env.JWT_REFRESH_EXPIRES_IN ?? '30d';
function signAccessToken(payload) {
    return jsonwebtoken_1.default.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}
function signRefreshToken(payload) {
    return jsonwebtoken_1.default.sign(payload, JWT_REFRESH_SECRET, { expiresIn: JWT_REFRESH_EXPIRES_IN });
}
function verifyAccessToken(token) {
    return jsonwebtoken_1.default.verify(token, JWT_SECRET);
}
function verifyRefreshToken(token) {
    return jsonwebtoken_1.default.verify(token, JWT_REFRESH_SECRET);
}
async function issueTokenPair(uid, email) {
    const payload = { uid, email };
    const accessToken = signAccessToken(payload);
    const refreshToken = signRefreshToken(payload);
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 30);
    await client_1.prisma.refreshToken.create({
        data: {
            userId: uid,
            token: refreshToken,
            expiresAt,
        },
    });
    return { accessToken, refreshToken };
}
async function revokeRefreshToken(token) {
    await client_1.prisma.refreshToken.deleteMany({ where: { token } });
}
//# sourceMappingURL=jwt.js.map