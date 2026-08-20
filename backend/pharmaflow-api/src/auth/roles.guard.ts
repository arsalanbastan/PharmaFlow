import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import type { AuthenticatedRequest } from './auth-request';
import { AUTH_ROLES_KEY } from './roles.decorator';
import type { AppUserRole } from './auth.types';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<AppUserRole[]>(
      AUTH_ROLES_KEY,
      [context.getHandler(), context.getClass()],
    );

    if (roles == null || roles.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    const principal = request.pharmaflowUser;

    if (principal == null || !roles.includes(principal.role)) {
      throw new ForbiddenException(
        'This operation is not allowed for the current role.',
      );
    }

    return true;
  }
}
