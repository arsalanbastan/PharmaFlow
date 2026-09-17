import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';

@Injectable()
export class OrdersAvailabilityGuard implements CanActivate {
  canActivate(_context: ExecutionContext): boolean {
    const enabled =
      process.env.ORDERS_API_ENABLED?.trim().toLowerCase() === 'true';

    if (!enabled) {
      throw new ServiceUnavailableException('Orders API is not enabled yet.');
    }

    return true;
  }
}
