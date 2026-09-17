import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';

import { AuditContextService } from '../audit/audit-context.service';
import { AuthService } from './auth.service';
import type { AuthenticatedRequest } from './auth-request';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly authService: AuthService,
    private readonly auditContext: AuditContextService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    const authorization =
      typeof request.headers.authorization === 'string'
        ? request.headers.authorization
        : undefined;

    const principal =
      await this.authService.authenticateAuthorization(authorization);

    request.pharmaflowUser = principal;

    this.auditContext.setAuthenticatedActor({
      userId: principal.userId,
      displayName: principal.displayName,
      role: principal.role,
    });

    return true;
  }
}
