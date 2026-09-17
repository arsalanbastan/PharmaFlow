import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  OnModuleInit,
  UnauthorizedException,
} from '@nestjs/common';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { CreateAppUserDto } from './dto/create-app-user.dto';
import { LoginDto } from './dto/login.dto';
import { ResetAppUserPasswordDto } from './dto/reset-app-user-password.dto';
import { SetAppUserActiveDto } from './dto/set-app-user-active.dto';
import { SetAppUserPermissionsDto } from './dto/set-app-user-permissions.dto';
import { hashPassword, verifyPassword } from './auth-password';
import { createOpaqueSessionToken, hashSessionToken } from './auth-token';
import {
  APP_USER_ROLES,
  AppUserPermissions,
  AppUserRole,
  AuthPrincipal,
  PublicAppUser,
} from './auth.types';

const DEFAULT_SESSION_DAYS = 30;
const MAX_SESSION_DAYS = 90;
const DEFAULT_ACTIVITY_LIMIT = 100;
const MAX_ACTIVITY_LIMIT = 200;

type AppUserPermissionSource = {
  role: string;
  managerAppAccess?: boolean;
  canCreateOrders?: boolean;
  canCreateCheques?: boolean;
  canCreateCashPayments?: boolean;
  canViewFinancialReports?: boolean;
};

const FULL_MANAGER_PERMISSIONS: AppUserPermissions = {
  managerAppAccess: true,
  canCreateOrders: true,
  canCreateCheques: true,
  canCreateCashPayments: true,
  canViewFinancialReports: true,
};

@Injectable()
export class AuthService implements OnModuleInit {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async onModuleInit(): Promise<void> {
    await this.bootstrapUserFromEnvironment();
  }

  async login(dto: LoginDto) {
    const username = this.normalizeUsername(dto.username);

    const user = await this.prisma.appUser.findUnique({
      where: {
        username,
      },
    });

    if (
      user == null ||
      !user.isActive ||
      !verifyPassword(dto.password, user.passwordHash)
    ) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    const token = createOpaqueSessionToken();
    const tokenHash = hashSessionToken(token);
    const expiresAt = new Date(
      Date.now() + this.sessionDays() * 24 * 60 * 60 * 1000,
    );

    await this.prisma.authSession.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      },
    });

    return {
      token,
      expiresAt: expiresAt.toISOString(),
      user: this.toPublicUser(user),
    };
  }

  async authenticateAuthorization(
    authorization: string | undefined,
  ): Promise<AuthPrincipal> {
    const token = this.readBearerToken(authorization);
    const tokenHash = hashSessionToken(token);

    const session = await this.prisma.authSession.findUnique({
      where: {
        tokenHash,
      },
      include: {
        user: true,
      },
    });

    if (
      session == null ||
      session.revokedAt != null ||
      session.expiresAt.getTime() <= Date.now() ||
      !session.user.isActive
    ) {
      throw new UnauthorizedException('Invalid or expired session.');
    }

    return {
      userId: session.user.id,
      username: session.user.username,
      displayName: session.user.displayName,
      role: this.readRole(session.user.role),
      permissions: this.toPermissions(session.user),
    };
  }

  async logout(authorization: string | undefined): Promise<void> {
    const token = this.readBearerToken(authorization);
    const tokenHash = hashSessionToken(token);

    await this.prisma.authSession.updateMany({
      where: {
        tokenHash,
        revokedAt: null,
      },
      data: {
        revokedAt: new Date(),
      },
    });
  }

  async listUsers(): Promise<PublicAppUser[]> {
    const users = await this.prisma.appUser.findMany({
      orderBy: [
        {
          displayName: 'asc',
        },
        {
          username: 'asc',
        },
      ],
    });

    return users.map((user) => this.toPublicUser(user));
  }

  async createUser(dto: CreateAppUserDto): Promise<PublicAppUser> {
    const username = this.normalizeUsername(dto.username);

    const existing = await this.prisma.appUser.findUnique({
      where: {
        username,
      },
      select: {
        id: true,
      },
    });

    if (existing != null) {
      throw new ConflictException('Username already exists.');
    }

    return this.prisma.$transaction(async (tx) => {
      const permissions = this.permissionDataForCreate(dto);

      const user = await tx.appUser.create({
        data: {
          username,
          displayName: dto.displayName.trim(),
          passwordHash: hashPassword(dto.password),
          role: dto.role,
          ...permissions,
        },
      });

      const publicUser = this.toPublicUser(user);

      await this.auditLog.record(
        {
          action: 'USER_CREATED',
          entityType: 'APP_USER',
          entityId: user.id,
          after: publicUser,
        },
        tx,
      );

      return publicUser;
    });
  }

  async resetPassword(
    userId: string,
    dto: ResetAppUserPasswordDto,
  ): Promise<void> {
    await this.prisma.$transaction(async (tx) => {
      await tx.appUser.update({
        where: {
          id: userId,
        },
        data: {
          passwordHash: hashPassword(dto.password),
        },
      });

      await tx.authSession.updateMany({
        where: {
          userId,
          revokedAt: null,
        },
        data: {
          revokedAt: new Date(),
        },
      });

      await this.auditLog.record(
        {
          action: 'PASSWORD_RESET',
          entityType: 'APP_USER',
          entityId: userId,
          after: {
            passwordReset: true,
            sessionsRevoked: true,
          },
        },
        tx,
      );
    });
  }

  async setActive(
    userId: string,
    dto: SetAppUserActiveDto,
    actorUserId?: string,
  ): Promise<PublicAppUser> {
    if (!dto.isActive && actorUserId === userId) {
      throw new BadRequestException(
        'The current manager cannot deactivate their own account.',
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const before = await tx.appUser.findUnique({
        where: {
          id: userId,
        },
      });

      if (before == null) {
        throw new NotFoundException('User not found.');
      }

      const user = await tx.appUser.update({
        where: {
          id: userId,
        },
        data: {
          isActive: dto.isActive,
        },
      });

      if (!dto.isActive) {
        await tx.authSession.updateMany({
          where: {
            userId,
            revokedAt: null,
          },
          data: {
            revokedAt: new Date(),
          },
        });
      }

      const publicUser = this.toPublicUser(user);

      await this.auditLog.record(
        {
          action: dto.isActive ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
          entityType: 'APP_USER',
          entityId: userId,
          before: this.toPublicUser(before),
          after: publicUser,
        },
        tx,
      );

      return publicUser;
    });
  }

  async setPermissions(
    userId: string,
    dto: SetAppUserPermissionsDto,
  ): Promise<PublicAppUser> {
    return this.prisma.$transaction(async (tx) => {
      const before = await tx.appUser.findUnique({
        where: {
          id: userId,
        },
      });

      if (before == null) {
        throw new NotFoundException('User not found.');
      }

      const role = this.readRole(before.role);

      if (
        role === 'MANAGER' &&
        Object.values(dto).some((value) => value !== true)
      ) {
        throw new BadRequestException(
          'Manager permissions cannot be restricted.',
        );
      }

      const user = await tx.appUser.update({
        where: {
          id: userId,
        },
        data: {
          managerAppAccess: role === 'MANAGER' ? true : dto.managerAppAccess,
          canCreateOrders: role === 'MANAGER' ? true : dto.canCreateOrders,
          canCreateCheques: role === 'MANAGER' ? true : dto.canCreateCheques,
          canCreateCashPayments:
            role === 'MANAGER' ? true : dto.canCreateCashPayments,
          canViewFinancialReports:
            role === 'MANAGER' ? true : dto.canViewFinancialReports,
        },
      });

      const publicUser = this.toPublicUser(user);

      await this.auditLog.record(
        {
          action: 'PERMISSIONS_UPDATED',
          entityType: 'APP_USER',
          entityId: userId,
          before: {
            permissions: this.toPermissions(before),
          },
          after: {
            permissions: publicUser.permissions,
          },
        },
        tx,
      );

      return publicUser;
    });
  }

  async listUserActivity(userId: string, rawLimit?: string) {
    const parsed = Number.parseInt(rawLimit ?? '', 10);
    const limit = Number.isInteger(parsed)
      ? Math.min(Math.max(parsed, 1), MAX_ACTIVITY_LIMIT)
      : DEFAULT_ACTIVITY_LIMIT;

    return this.prisma.auditLog.findMany({
      where: {
        OR: [
          {
            actorUserId: userId,
          },
          {
            entityType: 'APP_USER',
            entityId: userId,
          },
        ],
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: limit,
    });
  }

  private permissionDataForCreate(dto: CreateAppUserDto): AppUserPermissions {
    if (dto.role === 'MANAGER') {
      return {
        ...FULL_MANAGER_PERMISSIONS,
      };
    }

    return {
      managerAppAccess: dto.managerAppAccess ?? false,
      canCreateOrders: dto.canCreateOrders ?? true,
      canCreateCheques: dto.canCreateCheques ?? false,
      canCreateCashPayments: dto.canCreateCashPayments ?? false,
      canViewFinancialReports: dto.canViewFinancialReports ?? false,
    };
  }

  private toPermissions(user: AppUserPermissionSource): AppUserPermissions {
    if (this.readRole(user.role) === 'MANAGER') {
      return {
        ...FULL_MANAGER_PERMISSIONS,
      };
    }

    return {
      managerAppAccess: user.managerAppAccess === true,
      canCreateOrders: user.canCreateOrders !== false,
      canCreateCheques: user.canCreateCheques === true,
      canCreateCashPayments: user.canCreateCashPayments === true,
      canViewFinancialReports: user.canViewFinancialReports === true,
    };
  }

  private normalizeUsername(raw: string): string {
    const normalized = raw.normalize('NFKC').trim().toLowerCase();

    if (normalized.length === 0) {
      throw new UnauthorizedException('Invalid credentials.');
    }

    return normalized;
  }

  private readBearerToken(authorization: string | undefined): string {
    const value = authorization?.trim() ?? '';

    if (!value.startsWith('Bearer ')) {
      throw new UnauthorizedException('Bearer token is required.');
    }

    const token = value.slice('Bearer '.length).trim();

    if (token.length < 20) {
      throw new UnauthorizedException('Invalid session token.');
    }

    return token;
  }

  private sessionDays(): number {
    const parsed = Number.parseInt(process.env.AUTH_SESSION_DAYS ?? '', 10);

    if (!Number.isInteger(parsed) || parsed <= 0) {
      return DEFAULT_SESSION_DAYS;
    }

    return Math.min(parsed, MAX_SESSION_DAYS);
  }

  private readRole(raw: string): AppUserRole {
    if ((APP_USER_ROLES as readonly string[]).includes(raw)) {
      return raw as AppUserRole;
    }

    throw new UnauthorizedException('User role is invalid.');
  }

  private toPublicUser(user: {
    id: string;
    username: string;
    displayName: string;
    role: string;
    isActive: boolean;
    managerAppAccess?: boolean;
    canCreateOrders?: boolean;
    canCreateCheques?: boolean;
    canCreateCashPayments?: boolean;
    canViewFinancialReports?: boolean;
  }): PublicAppUser {
    return {
      userId: user.id,
      username: user.username,
      displayName: user.displayName,
      role: this.readRole(user.role),
      isActive: user.isActive,
      permissions: this.toPermissions(user),
    };
  }

  private async bootstrapUserFromEnvironment(): Promise<void> {
    const rawUsername = process.env.AUTH_BOOTSTRAP_USERNAME?.trim();

    const password = process.env.AUTH_BOOTSTRAP_PASSWORD ?? '';

    if (!rawUsername && !password) {
      return;
    }

    if (!rawUsername || password.length < 6) {
      throw new Error(
        'AUTH_BOOTSTRAP_USERNAME and a password of at least 6 characters must be provided together.',
      );
    }

    const username = this.normalizeUsername(rawUsername);
    const displayName =
      process.env.AUTH_BOOTSTRAP_DISPLAY_NAME?.trim() || rawUsername;

    const roleRaw =
      process.env.AUTH_BOOTSTRAP_ROLE?.trim().toUpperCase() || 'MANAGER';

    const role = this.readRole(roleRaw);

    const existing = await this.prisma.appUser.findUnique({
      where: {
        username,
      },
      select: {
        id: true,
      },
    });

    if (existing != null) {
      return;
    }

    await this.prisma.appUser.create({
      data: {
        username,
        displayName,
        passwordHash: hashPassword(password),
        role,
        ...(role === 'MANAGER'
          ? {
              ...FULL_MANAGER_PERMISSIONS,
            }
          : {}),
      },
    });

    console.log(
      `[Auth] Bootstrap ${role} user created: ${username}. Remove bootstrap password from environment after verification.`,
    );
  }
}
