import {
  BadRequestException,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';

import { AuthService } from './auth.service';
import { hashPassword } from './auth-password';

describe('AuthService', () => {
  const prisma = {
    appUser: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    authSession: {
      create: jest.fn(),
      findUnique: jest.fn(),
      updateMany: jest.fn(),
    },
    auditLog: {
      findMany: jest.fn(),
    },
    $transaction: jest.fn(),
  };

  const auditLog = {
    record: jest.fn(),
  };

  let service: AuthService;

  beforeEach(() => {
    jest.clearAllMocks();
    delete process.env.AUTH_BOOTSTRAP_USERNAME;
    delete process.env.AUTH_BOOTSTRAP_PASSWORD;
    delete process.env.AUTH_BOOTSTRAP_DISPLAY_NAME;
    delete process.env.AUTH_BOOTSTRAP_ROLE;

    prisma.$transaction.mockImplementation(
      async (callback: (tx: typeof prisma) => unknown) => callback(prisma),
    );

    service = new AuthService(prisma as never, auditLog as never);
  });

  it('creates an opaque session for valid credentials', async () => {
    prisma.appUser.findUnique.mockResolvedValue({
      id: '11111111-1111-4111-8111-111111111111',
      username: 'arsalan',
      displayName: 'ارسلان',
      passwordHash: hashPassword('secret-123'),
      role: 'STAFF',
      isActive: true,
      managerAppAccess: false,
      canCreateOrders: true,
      canCreateCheques: false,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    });

    prisma.authSession.create.mockResolvedValue({
      id: 'session',
    });

    const result = await service.login({
      username: ' Arsalan ',
      password: 'secret-123',
    });

    expect(result.token.length).toBeGreaterThan(20);
    expect(result.user).toEqual(
      expect.objectContaining({
        userId: '11111111-1111-4111-8111-111111111111',
        username: 'arsalan',
        displayName: 'ارسلان',
        role: 'STAFF',
        permissions: {
          managerAppAccess: false,
          canCreateOrders: true,
          canCreateCheques: false,
          canCreateCashPayments: false,
          canViewFinancialReports: false,
        },
      }),
    );

    expect(prisma.authSession.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          userId: '11111111-1111-4111-8111-111111111111',
          tokenHash: expect.stringMatching(/^[0-9a-f]{64}$/),
        }),
      }),
    );
  });

  it('rejects invalid credentials with one generic error', async () => {
    prisma.appUser.findUnique.mockResolvedValue(null);

    await expect(
      service.login({
        username: 'unknown',
        password: 'secret-123',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('authenticates a manager with effective full permissions', async () => {
    prisma.authSession.findUnique.mockResolvedValue({
      id: 'session',
      revokedAt: null,
      expiresAt: new Date(Date.now() + 60_000),
      user: {
        id: '22222222-2222-4222-8222-222222222222',
        username: 'manager',
        displayName: 'مدیر',
        role: 'MANAGER',
        isActive: true,
        managerAppAccess: false,
        canCreateOrders: false,
        canCreateCheques: false,
        canCreateCashPayments: false,
        canViewFinancialReports: false,
      },
    });

    const principal = await service.authenticateAuthorization(
      `Bearer ${'x'.repeat(32)}`,
    );

    expect(principal).toEqual({
      userId: '22222222-2222-4222-8222-222222222222',
      username: 'manager',
      displayName: 'مدیر',
      role: 'MANAGER',
      permissions: {
        managerAppAccess: true,
        canCreateOrders: true,
        canCreateCheques: true,
        canCreateCashPayments: true,
        canViewFinancialReports: true,
      },
    });
  });

  it('prevents duplicate usernames', async () => {
    prisma.appUser.findUnique.mockResolvedValue({
      id: 'existing',
    });

    await expect(
      service.createUser({
        username: 'user1',
        displayName: 'User 1',
        password: 'secret-123',
        role: 'STAFF',
      }),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('updates staff permissions and records an audit event', async () => {
    const before = {
      id: '33333333-3333-4333-8333-333333333333',
      username: 'staff',
      displayName: 'Staff',
      role: 'STAFF',
      isActive: true,
      managerAppAccess: false,
      canCreateOrders: true,
      canCreateCheques: false,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    };

    prisma.appUser.findUnique.mockResolvedValue(before);
    prisma.appUser.update.mockResolvedValue({
      ...before,
      managerAppAccess: true,
      canCreateCheques: true,
    });

    const result = await service.setPermissions(before.id, {
      managerAppAccess: true,
      canCreateOrders: true,
      canCreateCheques: true,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    });

    expect(result.permissions.canCreateCheques).toBe(true);
    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'PERMISSIONS_UPDATED',
        entityType: 'APP_USER',
        entityId: before.id,
      }),
      prisma,
    );
  });

  it('prevents the current manager from deactivating themself', async () => {
    const id = '44444444-4444-4444-8444-444444444444';

    await expect(
      service.setActive(
        id,
        {
          isActive: false,
        },
        id,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
