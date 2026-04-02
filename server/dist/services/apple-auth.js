"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyAppleToken = verifyAppleToken;
const apple_signin_auth_1 = __importDefault(require("apple-signin-auth"));
async function verifyAppleToken(identityToken) {
    const appleIdTokenClaims = await apple_signin_auth_1.default.verifyIdToken(identityToken, {
        audience: process.env.APPLE_CLIENT_ID,
        ignoreExpiration: false,
    });
    if (!appleIdTokenClaims.sub) {
        throw new Error('Invalid Apple token');
    }
    return {
        uid: appleIdTokenClaims.sub,
        email: appleIdTokenClaims.email,
    };
}
//# sourceMappingURL=apple-auth.js.map