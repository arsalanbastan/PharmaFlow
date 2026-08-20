import { AuditContextService } from './audit-context.service';
import { AuditLogService } from './audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';

describe('AuditLogService', () => {
  let auditCreate: jest.Mock;
  let service: AuditLogService;

  beforeEach(() => {
    auditCreate = jest.fn().mockResolvedValue({
      id: 'audit-id',
    });

    const prisma = {
      auditLog: {
        create: auditCreate,
      },
    } as unknown as PrismaService;

    const context = {
      get: jest.fn().mockReturnValue({
        source: 'MOBILE_APP',
        actorDisplayName: 'ارسلان',
        actorUserId: undefined,
        actorVerified: false,
        deviceId: 'test-device',
        ipAddress: '127.0.0.1',
        requestId: 'request-1',
      }),
    } as unknown as AuditContextService;

    service = new AuditLogService(prisma, context);
  });

  it('never stores raw cheque imageData in audit JSON', async () => {
    const rawImage = 'BASE64_SECRET_IMAGE_CONTENT_123456789';

    await service.record({
      action: 'UPDATE',
      entityType: 'CHEQUE',
      entityId: 'cheque-id',

      before: {
        id: 'cheque-id',
        chequeNumber: '1001',
        imageData: rawImage,
      },

      after: {
        id: 'cheque-id',
        chequeNumber: '1001',
        imageData: rawImage + '_NEW',
      },
    });

    expect(auditCreate).toHaveBeenCalledTimes(1);

    const data = auditCreate.mock.calls[0][0].data;

    const serialized = JSON.stringify(data);

    expect(serialized).not.toContain(rawImage);

    expect(data.beforeData.imageData).toEqual({
      present: true,
      length: rawImage.length,
    });

    expect(data.afterData.imageData).toEqual({
      present: true,
      length: (rawImage + '_NEW').length,
    });
  });

  it('redacts password token and secret-like values', async () => {
    await service.record({
      action: 'UPDATE',
      entityType: 'TEST',
      entityId: 'test-id',

      before: {
        password: 'plain-password',
        accessToken: 'plain-token',
        apiSecret: 'plain-secret',
        safeValue: 'visible',
      },
    });

    const data = auditCreate.mock.calls[0][0].data;

    expect(data.beforeData).toEqual({
      password: '[REDACTED]',
      accessToken: '[REDACTED]',
      apiSecret: '[REDACTED]',
      safeValue: 'visible',
    });
  });

  it('stores current request actor metadata', async () => {
    await service.record({
      action: 'CREATE',
      entityType: 'COMPANY',
      entityId: 'company-id',
      after: {
        id: 'company-id',
        name: 'Test Company',
      },
    });

    const data = auditCreate.mock.calls[0][0].data;

    expect(data).toEqual(
      expect.objectContaining({
        source: 'MOBILE_APP',
        actorDisplayName: 'ارسلان',
        actorUserId: null,
        actorVerified: false,
        deviceId: 'test-device',
        ipAddress: '127.0.0.1',
        requestId: 'request-1',
        action: 'CREATE',
        entityType: 'COMPANY',
        entityId: 'company-id',
      }),
    );
  });
});
