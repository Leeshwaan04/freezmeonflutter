import { OAuth2Client } from 'google-auth-library';

const client = new OAuth2Client();

// Accept tokens from both web and iOS OAuth clients
const ALLOWED_AUDIENCES = [
  process.env.GOOGLE_CLIENT_ID!,                                              // web client
  '542457497074-3uq4cfeimroq5v6d711ip0r52gdle7jn.apps.googleusercontent.com', // iOS client
];

export interface GoogleUser {
  uid: string;
  email: string | undefined;
  name: string | undefined;
  picture: string | undefined;
}

export async function verifyGoogleToken(idToken: string): Promise<GoogleUser> {
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
