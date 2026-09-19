"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.decodeActorDisplayNameHeader = decodeActorDisplayNameHeader;
const ACTOR_HEADER_PREFIX = 'utf8b64:';
const MAX_ACTOR_DISPLAY_NAME_LENGTH = 160;
const BASE64_PATTERN = /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/;
function decodeActorDisplayNameHeader(value) {
    const raw = value?.trim();
    if (!raw) {
        return undefined;
    }
    if (!raw.startsWith(ACTOR_HEADER_PREFIX)) {
        return raw.slice(0, MAX_ACTOR_DISPLAY_NAME_LENGTH);
    }
    const encoded = raw.slice(ACTOR_HEADER_PREFIX.length);
    if (!encoded || !BASE64_PATTERN.test(encoded)) {
        return undefined;
    }
    try {
        const bytes = Buffer.from(encoded, 'base64');
        if (bytes.toString('base64') !== encoded) {
            return undefined;
        }
        const decoded = bytes.toString('utf8').trim();
        if (!decoded) {
            return undefined;
        }
        return decoded.slice(0, MAX_ACTOR_DISPLAY_NAME_LENGTH);
    }
    catch {
        return undefined;
    }
}
//# sourceMappingURL=audit-actor-header.js.map