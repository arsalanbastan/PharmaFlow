import { randomBytes, scryptSync, timingSafeEqual } from 'node:crypto';

const PASSWORD_PREFIX = 'scrypt';
const SALT_BYTES = 16;
const KEY_LENGTH = 64;

export function hashPassword(password: string): string {
  const normalized = password.normalize('NFKC');

  if (normalized.length < 6) {
    throw new Error('Password must contain at least 6 characters.');
  }

  const salt = randomBytes(SALT_BYTES);
  const derived = scryptSync(normalized, salt, KEY_LENGTH);

  return [
    PASSWORD_PREFIX,
    salt.toString('base64url'),
    derived.toString('base64url'),
  ].join('$');
}

export function verifyPassword(password: string, encoded: string): boolean {
  const parts = encoded.split('$');

  if (parts.length !== 3 || parts[0] !== PASSWORD_PREFIX) {
    return false;
  }

  try {
    const salt = Buffer.from(parts[1], 'base64url');
    const expected = Buffer.from(parts[2], 'base64url');
    const actual = scryptSync(
      password.normalize('NFKC'),
      salt,
      expected.length,
    );

    if (actual.length !== expected.length) {
      return false;
    }

    return timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}
