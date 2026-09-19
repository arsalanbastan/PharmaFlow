import { CanActivate, ExecutionContext } from '@nestjs/common';
export declare class OrdersAvailabilityGuard implements CanActivate {
    canActivate(_context: ExecutionContext): boolean;
}
