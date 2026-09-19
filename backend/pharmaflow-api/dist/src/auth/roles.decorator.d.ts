import type { AppUserRole } from './auth.types';
export declare const AUTH_ROLES_KEY = "pharmaflow-auth-roles";
export declare const Roles: (...roles: AppUserRole[]) => import("@nestjs/common").CustomDecorator<string>;
