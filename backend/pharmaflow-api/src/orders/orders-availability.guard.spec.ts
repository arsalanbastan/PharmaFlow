import { ServiceUnavailableException } from '@nestjs/common';

import { OrdersAvailabilityGuard } from './orders-availability.guard';

describe('OrdersAvailabilityGuard', () => {
  const previous = process.env.ORDERS_API_ENABLED;

  afterEach(() => {
    if (previous == null) {
      delete process.env.ORDERS_API_ENABLED;
    } else {
      process.env.ORDERS_API_ENABLED = previous;
    }
  });

  it('blocks when the flag is absent', () => {
    delete process.env.ORDERS_API_ENABLED;

    const guard = new OrdersAvailabilityGuard();

    expect(() => guard.canActivate({} as never)).toThrow(
      ServiceUnavailableException,
    );
  });

  it('blocks when explicitly false', () => {
    process.env.ORDERS_API_ENABLED = 'false';

    const guard = new OrdersAvailabilityGuard();

    expect(() => guard.canActivate({} as never)).toThrow(
      ServiceUnavailableException,
    );
  });

  it('allows only explicit true', () => {
    process.env.ORDERS_API_ENABLED = 'true';

    const guard = new OrdersAvailabilityGuard();

    expect(guard.canActivate({} as never)).toBe(true);
  });
});
