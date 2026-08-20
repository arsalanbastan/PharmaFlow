import { SetMetadata } from '@nestjs/common';

import type { AppUserRole } from './auth.types';

export const AUTH_ROLES_KEY = 'pharmaflow-auth-roles';

export const Roles = (...roles: AppUserRole[]) =>
  SetMetadata(AUTH_ROLES_KEY, roles);
