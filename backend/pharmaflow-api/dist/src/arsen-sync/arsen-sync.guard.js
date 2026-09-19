"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ArsenSyncGuard = void 0;
const common_1 = require("@nestjs/common");
const node_crypto_1 = require("node:crypto");
function secureTextEquals(expected, actual) {
    const expectedBuffer = Buffer.from(expected, 'utf8');
    const actualBuffer = Buffer.from(actual, 'utf8');
    if (expectedBuffer.length !== actualBuffer.length) {
        return false;
    }
    return (0, node_crypto_1.timingSafeEqual)(expectedBuffer, actualBuffer);
}
let ArsenSyncGuard = class ArsenSyncGuard {
    canActivate(context) {
        const expected = process.env.ARSEN_SYNC_KEY?.trim() ?? '';
        if (!expected) {
            throw new common_1.ServiceUnavailableException('Arsen sync is not configured.');
        }
        const request = context.switchToHttp().getRequest();
        const raw = request.headers['x-arsen-sync-key'];
        const actual = Array.isArray(raw) ? raw[0] : String(raw ?? '');
        if (!actual || !secureTextEquals(expected, actual)) {
            throw new common_1.UnauthorizedException('Invalid Arsen sync key.');
        }
        return true;
    }
};
exports.ArsenSyncGuard = ArsenSyncGuard;
exports.ArsenSyncGuard = ArsenSyncGuard = __decorate([
    (0, common_1.Injectable)()
], ArsenSyncGuard);
//# sourceMappingURL=arsen-sync.guard.js.map