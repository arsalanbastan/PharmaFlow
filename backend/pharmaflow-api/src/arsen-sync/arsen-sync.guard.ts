import {
  CanActivate,
  ExecutionContext,
  Injectable,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import { timingSafeEqual } from 'node:crypto';
import type { Request } from 'express';

function secureTextEquals(expected: string, actual: string): boolean {
  const expectedBuffer = Buffer.from(expected, 'utf8');
  const actualBuffer = Buffer.from(actual, 'utf8');

  if (expectedBuffer.length !== actualBuffer.length) {
    return false;
  }

  return timingSafeEqual(expectedBuffer, actualBuffer);
}

@Injectable()
export class ArsenSyncGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const expected = process.env.ARSEN_SYNC_KEY?.trim() ?? '';

    if (!expected) {
      throw new ServiceUnavailableException('Arsen sync is not configured.');
    }

    const request = context.switchToHttp().getRequest<Request>();
    const raw = request.headers['x-arsen-sync-key'];
    const actual = Array.isArray(raw) ? raw[0] : String(raw ?? '');

    if (!actual || !secureTextEquals(expected, actual)) {
      throw new UnauthorizedException('Invalid Arsen sync key.');
    }

    return true;
  }
}
