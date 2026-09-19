import type { AppUserPermissions } from './auth.types';
export declare const AUTH_PERMISSIONS_KEY = "pharmaflow:auth-permissions";
export type AppUserPermissionKey = keyof AppUserPermissions;
export declare const Permissions: (...permissions: AppUserPermissionKey[]) => import("@nestjs/common").CustomDecorator<string>;
