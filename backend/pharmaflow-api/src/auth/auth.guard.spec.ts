import { AuthGuard } from './auth.guard';

describe('AuthGuard audit binding', () => {
  it('stores the authenticated principal on request and audit context', async () => {
    const principal = {
      userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      username: 'amir',
      displayName: 'امیر',
      role: 'STAFF',
    };

    const authService = {
      authenticateAuthorization: jest.fn().mockResolvedValue(principal),
    };

    const auditContext = {
      setAuthenticatedActor: jest.fn(),
    };

    const request = {
      headers: {
        authorization: 'Bearer token-token-token-token',
      },
    };

    const context = {
      switchToHttp: () => ({
        getRequest: () => request,
      }),
    };

    const guard = new AuthGuard(authService as never, auditContext as never);

    await expect(guard.canActivate(context as never)).resolves.toBe(true);

    expect(request).toEqual(
      expect.objectContaining({
        pharmaflowUser: principal,
      }),
    );

    expect(auditContext.setAuthenticatedActor).toHaveBeenCalledWith({
      userId: principal.userId,
      displayName: principal.displayName,
      role: principal.role,
    });
  });
});
