"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthGuard = void 0;
const common_1 = require("@nestjs/common");
const audit_context_service_1 = require("../audit/audit-context.service");
const auth_service_1 = require("./auth.service");
let AuthGuard = class AuthGuard {
    authService;
    auditContext;
    constructor(authService, auditContext) {
        this.authService = authService;
        this.auditContext = auditContext;
    }
    async canActivate(context) {
        const request = context.switchToHttp().getRequest();
        const authorization = typeof request.headers.authorization === 'string'
            ? request.headers.authorization
            : undefined;
        const principal = await this.authService.authenticateAuthorization(authorization);
        request.pharmaflowUser = principal;
        this.auditContext.setAuthenticatedActor({
            userId: principal.userId,
            displayName: principal.displayName,
            role: principal.role,
        });
        return true;
    }
};
exports.AuthGuard = AuthGuard;
exports.AuthGuard = AuthGuard = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [auth_service_1.AuthService,
        audit_context_service_1.AuditContextService])
], AuthGuard);
//# sourceMappingURL=auth.guard.js.map