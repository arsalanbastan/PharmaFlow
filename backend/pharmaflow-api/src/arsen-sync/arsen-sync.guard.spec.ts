import { ExecutionContext, ServiceUnavailableException, UnauthorizedException } from '@nestjs/common';

import { ArsenSyncGuard } from './arsen-sync.guard';

describe('ArsenSyncGuard', () => {
  const original = process.env.ARSEN_SYNC_KEY;

  afterEach(() => {
    if (original == null) {
      delete process.env.ARSEN_SYNC_KEY;
    } else {
      process.env.ARSEN_SYNC_KEY = original;
    }
  });

  function context(key?: string): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({ headers: key ? { 'x-arsen-sync-key': key } : {} }),
      }),
    } as unknown as ExecutionContext;
  }

  it('fails closed when no server key is configured', () => {
    delete process.env.ARSEN_SYNC_KEY;
    expect(() => new ArsenSyncGuard().canActivate(context())).toThrow(
      ServiceUnavailableException,
    );
  });

  it('rejects an invalid key', () => {
    process.env.ARSEN_SYNC_KEY = 'server-secret';
    expect(() => new ArsenSyncGuard().canActivate(context('wrong'))).toThrow(
      UnauthorizedException,
    );
  });

  it('accepts the configured key', () => {
    process.env.ARSEN_SYNC_KEY = 'server-secret';
    expect(new ArsenSyncGuard().canActivate(context('server-secret'))).toBe(true);
  });
});
