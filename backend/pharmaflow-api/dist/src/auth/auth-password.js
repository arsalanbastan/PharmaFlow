"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hashPassword = hashPassword;
exports.verifyPassword = verifyPassword;
const node_crypto_1 = require("node:crypto");
const PASSWORD_PREFIX = 'scrypt';
const SALT_BYTES = 16;
const KEY_LENGTH = 64;
function hashPassword(password) {
    const normalized = password.normalize('NFKC');
    if (normalized.length < 6) {
        throw new Error('Password must contain at least 6 characters.');
    }
    const salt = (0, node_crypto_1.randomBytes)(SALT_BYTES);
    const derived = (0, node_crypto_1.scryptSync)(normalized, salt, KEY_LENGTH);
    return [
        PASSWORD_PREFIX,
        salt.toString('base64url'),
        derived.toString('base64url'),
    ].join('$');
}
function verifyPassword(password, encoded) {
    const parts = encoded.split('$');
    if (parts.length !== 3 || parts[0] !== PASSWORD_PREFIX) {
        return false;
    }
    try {
        const salt = Buffer.from(parts[1], 'base64url');
        const expected = Buffer.from(parts[2], 'base64url');
        const actual = (0, node_crypto_1.scryptSync)(password.normalize('NFKC'), salt, expected.length);
        if (actual.length !== expected.length) {
            return false;
        }
        return (0, node_crypto_1.timingSafeEqual)(actual, expected);
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=auth-password.js.map