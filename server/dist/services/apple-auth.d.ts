export interface AppleUser {
    uid: string;
    email: string | undefined;
}
export declare function verifyAppleToken(identityToken: string): Promise<AppleUser>;
//# sourceMappingURL=apple-auth.d.ts.map