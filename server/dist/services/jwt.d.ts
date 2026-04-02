export interface JwtPayload {
    uid: string;
    email?: string;
}
export declare function signAccessToken(payload: JwtPayload): string;
export declare function signRefreshToken(payload: JwtPayload): string;
export declare function verifyAccessToken(token: string): JwtPayload;
export declare function verifyRefreshToken(token: string): JwtPayload;
export declare function issueTokenPair(uid: string, email?: string): Promise<{
    accessToken: string;
    refreshToken: string;
}>;
export declare function revokeRefreshToken(token: string): Promise<void>;
//# sourceMappingURL=jwt.d.ts.map