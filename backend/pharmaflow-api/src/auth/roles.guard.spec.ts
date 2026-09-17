import { ForbiddenException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

import { RolesGuard } from './roles.guard';

describe('RolesGuard', () => {
  it('allows an authenticated manager when MANAGER is required', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue(['MANAGER']),
    } as unknown as Reflector;

    const guard = new RolesGuard(reflector);

    const context = {
      getHandler: () => function handler() {},
      getClass: () => class Controller {},
      switchToHttp: () => ({
        getRequest: () => ({
          pharmaflowUser: {
            userId: '1',
            username: 'manager',
            displayName: 'Manager',
            role: 'MANAGER',
          },
        }),
      }),
    };

    expect(guard.canActivate(context as never)).toBe(true);
  });

  it('rejects STAFF when MANAGER is required', () => {
    const reflector = {
      getAllAndOverride: jest.fn().mockReturnValue(['MANAGER']),
    } as unknown as Reflector;

    const guard = new RolesGuard(reflector);

    const context = {
      getHandler: () => function handler() {},
      getClass: () => class Controller {},
      switchToHttp: () => ({
        getRequest: () => ({
          pharmaflowUser: {
            userId: '2',
            username: 'staff',
            displayName: 'Staff',
            role: 'STAFF',
          },
        }),
      }),
    };

    expect(() => guard.canActivate(context as never)).toThrow(
      ForbiddenException,
    );
  });
});
