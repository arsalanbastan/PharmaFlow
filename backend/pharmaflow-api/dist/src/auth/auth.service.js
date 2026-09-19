"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthService = void 0;
const common_1 = require("@nestjs/common");
const audit_log_service_1 = require("../audit/audit-log.service");
const prisma_service_1 = require("../database/prisma/prisma.service");
const auth_password_1 = require("./auth-password");
const auth_token_1 = require("./auth-token");
const auth_types_1 = require("./auth.types");
const DEFAULT_SESSION_DAYS = 30;
const MAX_SESSION_DAYS = 90;
const DEFAULT_ACTIVITY_LIMIT = 100;
const MAX_ACTIVITY_LIMIT = 200;
const FULL_MANAGER_PERMISSIONS = {
    managerAppAccess: true,
    canCreateOrders: true,
    canCreateCheques: true,
    canCreateCashPayments: true,
    canViewFinancialReports: true,
};
let AuthService = class AuthService {
    prisma;
    auditLog;
    constructor(prisma, auditLog) {
        this.prisma = prisma;
        this.auditLog = auditLog;
    }
    async onModuleInit() {
        await this.bootstrapUserFromEnvironment();
    }
    async login(dto) {
        const username = this.normalizeUsername(dto.username);
        const user = await this.prisma.appUser.findUnique({
            where: {
                username,
            },
        });
        if (user == null ||
            !user.isActive ||
            !(0, auth_password_1.verifyPassword)(dto.password, user.passwordHash)) {
            throw new common_1.UnauthorizedException('Invalid credentials.');
        }
        const token = (0, auth_token_1.createOpaqueSessionToken)();
        const tokenHash = (0, auth_token_1.hashSessionToken)(token);
        const expiresAt = new Date(Date.now() + this.sessionDays() * 24 * 60 * 60 * 1000);
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
    async authenticateAuthorization(authorization) {
        const token = this.readBearerToken(authorization);
        const tokenHash = (0, auth_token_1.hashSessionToken)(token);
        const session = await this.prisma.authSession.findUnique({
            where: {
                tokenHash,
            },
            include: {
                user: true,
            },
        });
        if (session == null ||
            session.revokedAt != null ||
            session.expiresAt.getTime() <= Date.now() ||
            !session.user.isActive) {
            throw new common_1.UnauthorizedException('Invalid or expired session.');
        }
        return {
            userId: session.user.id,
            username: session.user.username,
            displayName: session.user.displayName,
            role: this.readRole(session.user.role),
            permissions: this.toPermissions(session.user),
        };
    }
    async logout(authorization) {
        const token = this.readBearerToken(authorization);
        const tokenHash = (0, auth_token_1.hashSessionToken)(token);
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
    async listUsers() {
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
    async createUser(dto) {
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
            throw new common_1.ConflictException('Username already exists.');
        }
        return this.prisma.$transaction(async (tx) => {
            const permissions = this.permissionDataForCreate(dto);
            const user = await tx.appUser.create({
                data: {
                    username,
                    displayName: dto.displayName.trim(),
                    passwordHash: (0, auth_password_1.hashPassword)(dto.password),
                    role: dto.role,
                    ...permissions,
                },
            });
            const publicUser = this.toPublicUser(user);
            await this.auditLog.record({
                action: 'USER_CREATED',
                entityType: 'APP_USER',
                entityId: user.id,
                after: publicUser,
            }, tx);
            return publicUser;
        });
    }
    async resetPassword(userId, dto) {
        await this.prisma.$transaction(async (tx) => {
            await tx.appUser.update({
                where: {
                    id: userId,
                },
                data: {
                    passwordHash: (0, auth_password_1.hashPassword)(dto.password),
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
            await this.auditLog.record({
                action: 'PASSWORD_RESET',
                entityType: 'APP_USER',
                entityId: userId,
                after: {
                    passwordReset: true,
                    sessionsRevoked: true,
                },
            }, tx);
        });
    }
    async setActive(userId, dto, actorUserId) {
        if (!dto.isActive && actorUserId === userId) {
            throw new common_1.BadRequestException('The current manager cannot deactivate their own account.');
        }
        return this.prisma.$transaction(async (tx) => {
            const before = await tx.appUser.findUnique({
                where: {
                    id: userId,
                },
            });
            if (before == null) {
                throw new common_1.NotFoundException('User not found.');
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
            await this.auditLog.record({
                action: dto.isActive ? 'USER_ACTIVATED' : 'USER_DEACTIVATED',
                entityType: 'APP_USER',
                entityId: userId,
                before: this.toPublicUser(before),
                after: publicUser,
            }, tx);
            return publicUser;
        });
    }
    async setPermissions(userId, dto) {
        return this.prisma.$transaction(async (tx) => {
            const before = await tx.appUser.findUnique({
                where: {
                    id: userId,
                },
            });
            if (before == null) {
                throw new common_1.NotFoundException('User not found.');
            }
            const role = this.readRole(before.role);
            if (role === 'MANAGER' &&
                Object.values(dto).some((value) => value !== true)) {
                throw new common_1.BadRequestException('Manager permissions cannot be restricted.');
            }
            const user = await tx.appUser.update({
                where: {
                    id: userId,
                },
                data: {
                    managerAppAccess: role === 'MANAGER' ? true : dto.managerAppAccess,
                    canCreateOrders: role === 'MANAGER' ? true : dto.canCreateOrders,
                    canCreateCheques: role === 'MANAGER' ? true : dto.canCreateCheques,
                    canCreateCashPayments: role === 'MANAGER' ? true : dto.canCreateCashPayments,
                    canViewFinancialReports: role === 'MANAGER' ? true : dto.canViewFinancialReports,
                },
            });
            const publicUser = this.toPublicUser(user);
            await this.auditLog.record({
                action: 'PERMISSIONS_UPDATED',
                entityType: 'APP_USER',
                entityId: userId,
                before: {
                    permissions: this.toPermissions(before),
                },
                after: {
                    permissions: publicUser.permissions,
                },
            }, tx);
            return publicUser;
        });
    }
    async listUserActivity(userId, rawLimit) {
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
    permissionDataForCreate(dto) {
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
    toPermissions(user) {
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
    normalizeUsername(raw) {
        const normalized = raw.normalize('NFKC').trim().toLowerCase();
        if (normalized.length === 0) {
            throw new common_1.UnauthorizedException('Invalid credentials.');
        }
        return normalized;
    }
    readBearerToken(authorization) {
        const value = authorization?.trim() ?? '';
        if (!value.startsWith('Bearer ')) {
            throw new common_1.UnauthorizedException('Bearer token is required.');
        }
        const token = value.slice('Bearer '.length).trim();
        if (token.length < 20) {
            throw new common_1.UnauthorizedException('Invalid session token.');
        }
        return token;
    }
    sessionDays() {
        const parsed = Number.parseInt(process.env.AUTH_SESSION_DAYS ?? '', 10);
        if (!Number.isInteger(parsed) || parsed <= 0) {
            return DEFAULT_SESSION_DAYS;
        }
        return Math.min(parsed, MAX_SESSION_DAYS);
    }
    readRole(raw) {
        if (auth_types_1.APP_USER_ROLES.includes(raw)) {
            return raw;
        }
        throw new common_1.UnauthorizedException('User role is invalid.');
    }
    toPublicUser(user) {
        return {
            userId: user.id,
            username: user.username,
            displayName: user.displayName,
            role: this.readRole(user.role),
            isActive: user.isActive,
            permissions: this.toPermissions(user),
        };
    }
    async bootstrapUserFromEnvironment() {
        const rawUsername = process.env.AUTH_BOOTSTRAP_USERNAME?.trim();
        const password = process.env.AUTH_BOOTSTRAP_PASSWORD ?? '';
        if (!rawUsername && !password) {
            return;
        }
        if (!rawUsername || password.length < 6) {
            throw new Error('AUTH_BOOTSTRAP_USERNAME and a password of at least 6 characters must be provided together.');
        }
        const username = this.normalizeUsername(rawUsername);
        const displayName = process.env.AUTH_BOOTSTRAP_DISPLAY_NAME?.trim() || rawUsername;
        const roleRaw = process.env.AUTH_BOOTSTRAP_ROLE?.trim().toUpperCase() || 'MANAGER';
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
                passwordHash: (0, auth_password_1.hashPassword)(password),
                role,
                ...(role === 'MANAGER'
                    ? {
                        ...FULL_MANAGER_PERMISSIONS,
                    }
                    : {}),
            },
        });
        console.log(`[Auth] Bootstrap ${role} user created: ${username}. Remove bootstrap password from environment after verification.`);
    }
};
exports.AuthService = AuthService;
exports.AuthService = AuthService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [prisma_service_1.PrismaService,
        audit_log_service_1.AuditLogService])
], AuthService);
//# sourceMappingURL=auth.service.js.map