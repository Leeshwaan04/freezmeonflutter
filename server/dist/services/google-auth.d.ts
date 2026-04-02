export interface GoogleUser {
    uid: string;
    email: string | undefined;
    name: string | undefined;
    picture: string | undefined;
}
export declare function verifyGoogleToken(idToken: string): Promise<GoogleUser>;
//# sourceMappingURL=google-auth.d.ts.map