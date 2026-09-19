import { AuthService } from './auth.service';
import { CreateAppUserDto } from './dto/create-app-user.dto';
import { LoginDto } from './dto/login.dto';
import { ResetAppUserPasswordDto } from './dto/reset-app-user-password.dto';
import { SetAppUserActiveDto } from './dto/set-app-user-active.dto';
import { SetAppUserPermissionsDto } from './dto/set-app-user-permissions.dto';
import type { AuthPrincipal } from './auth.types';
export declare class AuthController {
    private readonly authService;
    constructor(authService: AuthService);
    login(dto: LoginDto): Promise<{
        token: string;
        expiresAt: string;
        user: import("./auth.types").PublicAppUser;
    }>;
    me(user: AuthPrincipal): {
        user: AuthPrincipal;
    };
    logout(authorization?: string): Promise<{
        ok: boolean;
    }>;
    listUsers(): Promise<import("./auth.types").PublicAppUser[]>;
    createUser(dto: CreateAppUserDto): Promise<import("./auth.types").PublicAppUser>;
    resetPassword(id: string, dto: ResetAppUserPasswordDto): Promise<{
        ok: boolean;
    }>;
    setActive(currentUser: AuthPrincipal, id: string, dto: SetAppUserActiveDto): Promise<import("./auth.types").PublicAppUser>;
    setPermissions(id: string, dto: SetAppUserPermissionsDto): Promise<import("./auth.types").PublicAppUser>;
    listUserActivity(id: string, limit?: string): Promise<{
        id: string;
        createdAt: Date;
        source: string;
        actorDisplayName: string | null;
        actorUserId: string | null;
        actorVerified: boolean;
        deviceId: string | null;
        action: string;
        entityType: string;
        entityId: string | null;
        beforeData: import("@prisma/client/runtime/library").JsonValue | null;
        afterData: import("@prisma/client/runtime/library").JsonValue | null;
        ipAddress: string | null;
        requestId: string | null;
    }[]>;
}
