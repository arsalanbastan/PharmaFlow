import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import type { AuthenticatedRequest } from './auth-request';
import {
  AUTH_PERMISSIONS_KEY,
  type AppUserPermissionKey,
} from './permissions.decorator';

@Injectable()
export class PermissionsGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredPermissions = this.reflector.getAllAndOverride<
      AppUserPermissionKey[]
    >(AUTH_PERMISSIONS_KEY, [context.getHandler(), context.getClass()]);

    if (requiredPermissions == null || requiredPermissions.length === 0) {
      return true;
    }

    const request = context.switchToHttp().getRequest<AuthenticatedRequest>();

    const principal = request.pharmaflowUser;

    if (principal == null) {
      throw new ForbiddenException('Authenticated user context is required.');
    }

    const missing = requiredPermissions.find(
      (permission) => principal.permissions[permission] !== true,
    );

    if (missing != null) {
      throw new ForbiddenException(
        'This operation is not allowed for the current user.',
      );
    }

    return true;
  }
}
