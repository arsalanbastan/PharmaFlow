import { Reflector } from '@nestjs/core';

import { AUTH_PERMISSIONS_KEY } from '../auth/permissions.decorator';
import { PermissionsGuard } from '../auth/permissions.guard';
import { AUTH_ROLES_KEY } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { OrdersController } from './orders.controller';

describe('OrdersController Staff pending mutation access', () => {
  const principal = {
    userId: '22222222-2222-4222-8222-222222222222',
    username: 'staff',
    displayName: 'Staff User',
    role: 'STAFF',
    permissions: {
      managerAppAccess: false,
      canCreateOrders: true,
      canCreateCheques: false,
      canCreateCashPayments: false,
      canViewFinancialReports: false,
    },
  };

  const createContext = (handler: object) =>
    ({
      getHandler: () => handler,
      getClass: () => OrdersController,
      switchToHttp: () => ({
        getRequest: () => ({ pharmaflowUser: principal }),
      }),
    }) as never;

  it.each([
    ['edit', OrdersController.prototype.updatePending],
    ['delete', OrdersController.prototype.removePending],
  ])(
    'explicitly allows STAFF and MANAGER to %s PENDING requests',
    (_, handler) => {
      const reflector = new Reflector();
      const context = createContext(handler);

      expect(Reflect.getMetadata(AUTH_ROLES_KEY, handler)).toEqual([
        'STAFF',
        'MANAGER',
      ]);
      expect(Reflect.getMetadata(AUTH_PERMISSIONS_KEY, handler)).toEqual([
        'canCreateOrders',
      ]);
      expect(new RolesGuard(reflector).canActivate(context)).toBe(true);
      expect(new PermissionsGuard(reflector).canActivate(context)).toBe(true);
    },
  );
});
