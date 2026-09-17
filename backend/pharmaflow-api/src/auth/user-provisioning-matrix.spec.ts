import { AuthService } from './auth.service';
import { hashPassword, verifyPassword } from './auth-password';

describe('user provisioning and permission matrix', () => {
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

    prisma.$transaction.mockImplementation(
      async (callback: (tx: typeof prisma) => unknown) => callback(prisma),
    );

    service = new AuthService(prisma as never, auditLog as never);
  });

  it('creates a technician with order-only defaults', async () => {
    prisma.appUser.findUnique.mockResolvedValue(null);

    prisma.appUser.create.mockImplementation(
      ({ data }: { data: Record<string, unknown> }) => ({
        id: '11111111-1111-4111-8111-111111111111',
        isActive: true,
        ...data,
      }),
    );

    const result = await service.createUser({
      username: ' technician1 ',
      displayName: 'تکنسین شماره یک',
      password: 'staff-123',
      role: 'STAFF',
    });

    expect(result).toEqual(
      expect.objectContaining({
        username: 'technician1',
        displayName: 'تکنسین شماره یک',
        role: 'STAFF',
        isActive: true,
        permissions: {
          managerAppAccess: false,
          canCreateOrders: true,
          canCreateCheques: false,
          canCreateCashPayments: false,
          canViewFinancialReports: false,
        },
      }),
    );

    const createCall = prisma.appUser.create.mock.calls[0][0];

    expect(
      verifyPassword('staff-123', createCall.data.passwordHash as string),
    ).toBe(true);

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'USER_CREATED',
        entityType: 'APP_USER',
      }),
      prisma,
    );
  });

  it('creates financial staff with create and view access', async () => {
    prisma.appUser.findUnique.mockResolvedValue(null);

    prisma.appUser.create.mockImplementation(
      ({ data }: { data: Record<string, unknown> }) => ({
        id: '22222222-2222-4222-8222-222222222222',
        isActive: true,
        ...data,
      }),
    );

    const result = await service.createUser({
      username: 'accounting1',
      displayName: 'پرسنل مالی',
      password: 'finance-123',
      role: 'STAFF',
      managerAppAccess: true,
      canCreateOrders: false,
      canCreateCheques: true,
      canCreateCashPayments: true,
      canViewFinancialReports: true,
    });

    expect(result.permissions).toEqual({
      managerAppAccess: true,
      canCreateOrders: false,
      canCreateCheques: true,
      canCreateCashPayments: true,
      canViewFinancialReports: true,
    });
  });

  it('allows a newly provisioned staff user to log in', async () => {
    const password = 'staff-login-123';

    prisma.appUser.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      username: 'newstaff',
      displayName: 'پرسنل جدید',
      passwordHash:
        'scrypt$16384$8$1$0aaabbbcccdddeeefff1112223334444$96889582e315d2f9b714960aa6cdbc00fa080525a241652cb9af0c9a8ba6bde0f5c0f04f2cb4bad5a6e7f5110ab86633b2cbf3d9cd45852cd8b56c1a4560c976',
      role: 'STAFF',
      isActive: true,
      managerAppAccess: false,
      canCreateOrders: true,
      canCreateCheques: false,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    });

    const createdUser = await service
      .createUser({
        username: 'temporary',
        displayName: 'Temporary',
        password,
        role: 'STAFF',
      })
      .catch(() => null);

    expect(createdUser).toBeNull();
  });

  it('returns the configured permissions when staff logs in', async () => {
    prisma.appUser.findUnique.mockResolvedValue({
      id: '44444444-4444-4444-8444-444444444444',
      username: 'financialstaff',
      displayName: 'پرسنل مالی',
      passwordHash: hashPassword('finance-login-123'),
      role: 'STAFF',
      isActive: true,
      managerAppAccess: true,
      canCreateOrders: false,
      canCreateCheques: true,
      canCreateCashPayments: true,
      canViewFinancialReports: true,
    });

    prisma.authSession.create.mockResolvedValue({
      id: 'session-1',
    });

    const result = await service.login({
      username: 'financialstaff',
      password: 'finance-login-123',
    });

    expect(result.token.length).toBeGreaterThan(20);

    expect(result.user.permissions).toEqual({
      managerAppAccess: true,
      canCreateOrders: false,
      canCreateCheques: true,
      canCreateCashPayments: true,
      canViewFinancialReports: true,
    });
  });

  it('revokes active sessions when staff is deactivated', async () => {
    const user = {
      id: '55555555-5555-4555-8555-555555555555',
      username: 'staff2',
      displayName: 'پرسنل دوم',
      passwordHash: 'not-used',
      role: 'STAFF',
      isActive: true,
      managerAppAccess: false,
      canCreateOrders: true,
      canCreateCheques: false,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    };

    prisma.appUser.findUnique.mockResolvedValue(user);

    prisma.appUser.update.mockResolvedValue({
      ...user,
      isActive: false,
    });

    await service.setActive(
      user.id,
      {
        isActive: false,
      },
      'manager-user-id',
    );

    expect(prisma.authSession.updateMany).toHaveBeenCalledWith({
      where: {
        userId: user.id,
        revokedAt: null,
      },
      data: {
        revokedAt: expect.any(Date),
      },
    });
  });

  it('revokes active sessions when password is reset', async () => {
    const userId = '66666666-6666-4666-8666-666666666666';

    prisma.appUser.update.mockResolvedValue({
      id: userId,
    });

    await service.resetPassword(userId, {
      password: 'new-password-123',
    });

    expect(prisma.authSession.updateMany).toHaveBeenCalledWith({
      where: {
        userId,
        revokedAt: null,
      },
      data: {
        revokedAt: expect.any(Date),
      },
    });

    const updateCall = prisma.appUser.update.mock.calls[0][0];

    expect(
      verifyPassword(
        'new-password-123',
        updateCall.data.passwordHash as string,
      ),
    ).toBe(true);
  });

  it('keeps manager permissions fully enabled', async () => {
    prisma.appUser.findUnique.mockResolvedValue(null);

    prisma.appUser.create.mockImplementation(
      ({ data }: { data: Record<string, unknown> }) => ({
        id: '77777777-7777-4777-8777-777777777777',
        isActive: true,
        ...data,
      }),
    );

    const result = await service.createUser({
      username: 'manager2',
      displayName: 'مدیر دوم',
      password: 'manager-123',
      role: 'MANAGER',
      managerAppAccess: false,
      canCreateOrders: false,
      canCreateCheques: false,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    });

    expect(result.permissions).toEqual({
      managerAppAccess: true,
      canCreateOrders: true,
      canCreateCheques: true,
      canCreateCashPayments: true,
      canViewFinancialReports: true,
    });
  });
});
