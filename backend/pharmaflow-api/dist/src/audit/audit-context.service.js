"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditContextService = void 0;
const common_1 = require("@nestjs/common");
const node_async_hooks_1 = require("node:async_hooks");
let AuditContextService = class AuditContextService {
    storage = new node_async_hooks_1.AsyncLocalStorage();
    run(context, callback) {
        return this.storage.run(context, callback);
    }
    get() {
        return this.storage.getStore();
    }
    setAuthenticatedActor(actor) {
        const context = this.storage.getStore();
        if (context == null) {
            return;
        }
        context.actorDisplayName = actor.displayName;
        context.actorUserId = actor.userId;
        context.actorRole = actor.role;
        context.actorVerified = true;
    }
};
exports.AuditContextService = AuditContextService;
exports.AuditContextService = AuditContextService = __decorate([
    (0, common_1.Injectable)()
], AuditContextService);
//# sourceMappingURL=audit-context.service.js.map