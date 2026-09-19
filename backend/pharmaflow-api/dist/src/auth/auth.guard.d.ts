import { CanActivate, ExecutionContext } from '@nestjs/common';
import { AuditContextService } from '../audit/audit-context.service';
import { AuthService } from './auth.service';
export declare class AuthGuard implements CanActivate {
    private readonly authService;
    private readonly auditContext;
    constructor(authService: AuthService, auditContext: AuditContextService);
    canActivate(context: ExecutionContext): Promise<boolean>;
}
