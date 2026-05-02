// Shared validation helpers used across route handlers
import sanitizeHtml from 'sanitize-html';

// Strip all HTML tags from user-supplied text fields to prevent XSS.
// Returns plain text only — no tags, no attributes.
export function sanitizeText(input: string): string {
  return sanitizeHtml(input, { allowedTags: [], allowedAttributes: {} });
}

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const VALID_INTENTS = ['meaningful', 'exploring', 'friendship'];
const VALID_DISTANCE_BUCKETS = ['10km', '25km', '50km', '100km', 'anywhere'];
const VALID_GENDERS = ['man', 'woman', 'nonbinary', 'other'];

export function isValidEmail(email: unknown): email is string {
  return typeof email === 'string' && EMAIL_RE.test(email) && email.length <= 254;
}

export function isValidPassword(password: unknown): password is string {
  return typeof password === 'string' && password.length >= 8 && password.length <= 128;
}

export function isValidLat(lat: unknown): lat is number {
  return typeof lat === 'number' && !isNaN(lat) && lat >= -90 && lat <= 90;
}

export function isValidLng(lng: unknown): lng is number {
  return typeof lng === 'number' && !isNaN(lng) && lng >= -180 && lng <= 180;
}

export function isValidIntent(intent: unknown): intent is string {
  return typeof intent === 'string' && VALID_INTENTS.includes(intent);
}

export function isValidDistanceBucket(bucket: unknown): bucket is string {
  return typeof bucket === 'string' && VALID_DISTANCE_BUCKETS.includes(bucket);
}

export function isValidGender(gender: unknown): gender is string {
  return typeof gender === 'string' && VALID_GENDERS.includes(gender);
}

export function isValidAge(age: unknown): age is number {
  return typeof age === 'number' && Number.isInteger(age) && age >= 18 && age <= 100;
}

export function isValidAgeRange(min: unknown, max: unknown): boolean {
  return isValidAge(min) && isValidAge(max) && (min as number) <= (max as number);
}

export function isValidName(name: unknown): name is string {
  return typeof name === 'string' && name.trim().length >= 1 && name.length <= 60;
}

export function isValidBio(bio: unknown): bio is string {
  return typeof bio === 'string' && bio.length <= 500;
}

export function isValidInterests(interests: unknown): boolean {
  return Array.isArray(interests) &&
    interests.length <= 30 &&
    interests.every((i) => typeof i === 'string' && i.length <= 60);
}
