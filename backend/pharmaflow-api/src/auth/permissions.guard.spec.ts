import { ForbiddenException } from '@nestjs/common';

import { PermissionsGuard } from './permissions.guard';

describe('PermissionsGuard', () => {
  const reflector = {
    getAllAndOverride: jest.fn(),
  };

  const context = (permissions: Record<string, boolean>) =>
    ({
      getHandler: jest.fn(),
      getClass: jest.fn(),
      switchToHttp: () => ({
        getRequest: () => ({
          pharmaflowUser: {
            userId: '11111111-1111-4111-8111-111111111111',
            username: 'staff',
            displayName: 'Staff',
            role: 'STAFF',
            permissions,
          },
        }),
      }),
    }) as never;

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('passes when no permission metadata is present', () => {
    reflector.getAllAndOverride.mockReturnValue(undefined);

    const guard = new PermissionsGuard(reflector as never);

    expect(guard.canActivate(context({}))).toBe(true);
  });

  it('allows the requested permission', () => {
    reflector.getAllAndOverride.mockReturnValue(['canCreateOrders']);

    const guard = new PermissionsGuard(reflector as never);

    expect(
      guard.canActivate(
        context({
          managerAppAccess: true,
          canCreateOrders: true,
          canCreateCheques: false,
          canCreateCashPayments: false,
          canViewFinancialReports: false,
        }),
      ),
    ).toBe(true);
  });

  it('rejects a missing permission', () => {
    reflector.getAllAndOverride.mockReturnValue(['canCreateOrders']);

    const guard = new PermissionsGuard(reflector as never);

    expect(() =>
      guard.canActivate(
        context({
          managerAppAccess: true,
          canCreateOrders: false,
          canCreateCheques: false,
          canCreateCashPayments: false,
          canViewFinancialReports: false,
        }),
      ),
    ).toThrow(ForbiddenException);
  });
});
