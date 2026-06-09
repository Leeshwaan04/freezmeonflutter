import { OAuth2Client } from 'google-auth-library';

const client = new OAuth2Client();

// Accept tokens from both web and iOS OAuth clients
const ALLOWED_AUDIENCES = [
  process.env.GOOGLE_CLIENT_ID!,         // web client
  process.env.GOOGLE_IOS_CLIENT_ID!,     // iOS client (required for app sign-in)
].filter(Boolean);

if (ALLOWED_AUDIENCES.length === 0) {
  console.warn('[google-auth] No Google OAuth audiences configured. Set GOOGLE_IOS_CLIENT_ID to enable iOS sign-in.');
}

export interface GoogleUser {
  uid: string;
  email: string | undefined;
  name: string | undefined;
  picture: string | undefined;
}

export async function verifyGoogleToken(idToken: string): Promise<GoogleUser> {
  if (ALLOWED_AUDIENCES.length === 0) {
    throw new Error('Google OAuth not configured (GOOGLE_IOS_CLIENT_ID missing)');
  }

  const ticket = await client.verifyIdToken({
    idToken,
    audience: ALLOWED_AUDIENCES,
  });

  const payload = ticket.getPayload();
  if (!payload || !payload.sub) {
    throw new Error('Invalid Google token');
  }

  return {
    uid: payload.sub,
    email: payload.email,
    name: payload.name,
    picture: payload.picture,
  };
}
