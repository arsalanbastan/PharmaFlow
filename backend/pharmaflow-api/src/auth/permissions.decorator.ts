import { SetMetadata } from '@nestjs/common';

import type { AppUserPermissions } from './auth.types';

export const AUTH_PERMISSIONS_KEY = 'pharmaflow:auth-permissions';

export type AppUserPermissionKey = keyof AppUserPermissions;

export const Permissions = (...permissions: AppUserPermissionKey[]) =>
  SetMetadata(AUTH_PERMISSIONS_KEY, permissions);
