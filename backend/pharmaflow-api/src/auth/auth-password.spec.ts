import { hashPassword, verifyPassword } from './auth-password';

describe('auth-password', () => {
  it('hashes without storing the plain password and verifies it', () => {
    const plain = 'safe-test-password';
    const encoded = hashPassword(plain);

    expect(encoded).toMatch(/^scrypt\$/);
    expect(encoded).not.toContain(plain);
    expect(verifyPassword(plain, encoded)).toBe(true);
    expect(verifyPassword('wrong-password', encoded)).toBe(false);
  });
});
