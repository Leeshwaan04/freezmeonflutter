import appleSignin from 'apple-signin-auth';

export interface AppleUser {
  uid: string;
  email: string | undefined;
}

export async function verifyAppleToken(identityToken: string): Promise<AppleUser> {
  const appleIdTokenClaims = await appleSignin.verifyIdToken(identityToken, {
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
