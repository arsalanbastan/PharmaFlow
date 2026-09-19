"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createOpaqueSessionToken = createOpaqueSessionToken;
exports.hashSessionToken = hashSessionToken;
const node_crypto_1 = require("node:crypto");
function createOpaqueSessionToken() {
    return (0, node_crypto_1.randomBytes)(32).toString('base64url');
}
function hashSessionToken(token) {
    return (0, node_crypto_1.createHash)('sha256').update(token, 'utf8').digest('hex');
}
//# sourceMappingURL=auth-token.js.map