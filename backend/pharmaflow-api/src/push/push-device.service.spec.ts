import { ForbiddenException } from '@nestjs/common';

import { PushDeviceService } from './push-device.service';

describe('PushDeviceService', () => {
  const manager = {
    userId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    username: 'manager',
    displayName: 'Manager',
    role: 'MANAGER' as const,
  };

  const staff = {
    ...manager,
    role: 'STAFF' as const,
  };

  const existingDevice = {
    id: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    userId: manager.userId,
    fcmToken: 'old-token-1234567890',
    installationId: 'install-12345678',
    platform: 'android',
    appPackage: 'com.example.pharmaflow.dev',
    isEnabled: true,
    createdAt: new Date('2026-08-18T10:00:00.000Z'),
    updatedAt: new Date('2026-08-18T10:00:00.000Z'),
    lastSeenAt: new Date('2026-08-18T10:00:00.000Z'),
    revokedAt: null,
    notificationAggregationVersion: 0,
  };

  const tx = {
    pushDevice: {
      findFirst: jest.fn(),
      deleteMany: jest.fn(),
      update: jest.fn(),
      create: jest.fn(),
    },
    pushDelivery: {
      updateMany: jest.fn(),
    },
  };

  const prisma = {
    pushDevice: {
      updateMany: jest.fn(),
    },
    pushDelivery: {
      findFirst: jest.fn(),
    },
    $transaction: jest.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) =>
        callback(tx),
    ),
  };

  let service: PushDeviceService;

  beforeEach(() => {
    jest.clearAllMocks();
    service = new PushDeviceService(prisma as never);
  });

  it('registers a MANAGER installation and never returns the FCM token', async () => {
    tx.pushDevice.findFirst.mockResolvedValue(existingDevice);
    tx.pushDevice.deleteMany.mockResolvedValue({ count: 0 });
    tx.pushDevice.update.mockResolvedValue({
      ...existingDevice,
      fcmToken: 'new-token-1234567890',
      lastSeenAt: new Date('2026-08-18T11:00:00.000Z'),
    });

    const result = await service.register(manager, {
      token: ' new-token-1234567890 ',
      installationId: existingDevice.installationId,
      platform: 'android',
      appPackage: existingDevice.appPackage,
      notificationAggregationVersion: 1,
    });

    expect(tx.pushDevice.update).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: existingDevice.id,
        },
        data: expect.objectContaining({
          fcmToken: 'new-token-1234567890',
          isEnabled: true,
          revokedAt: null,
          notificationAggregationVersion: 1,
        }),
      }),
    );

    expect(result).not.toHaveProperty('fcmToken');
    expect(result.id).toBe(existingDevice.id);
  });

  it('rejects STAFF registration before touching the database', async () => {
    await expect(
      service.register(staff, {
        token: 'new-token-1234567890',
        installationId: 'install-12345678',
        platform: 'android',
        appPackage: 'com.example.pharmaflow.dev',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('acknowledges only sent notifications up to the tapped delivery', async () => {
    const deliveryId =
      'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

    prisma.pushDelivery.findFirst.mockResolvedValue({
      id: deliveryId,
      deviceId: existingDevice.id,
      deliverySequence: 7n,
      outbox: {
        eventType: 'ORDER_CREATED',
      },
    });

    tx.pushDelivery.updateMany.mockResolvedValue({ count: 1 });

    await expect(
      service.acknowledgeNotification(manager, {
        deliveryId,
      }),
    ).resolves.toEqual({ ok: true });

    expect(tx.pushDelivery.updateMany).toHaveBeenNthCalledWith(1, {
      where: {
        id: deliveryId,
        acknowledgedAt: null,
      },
      data: {
        acknowledgedAt: expect.any(Date),
      },
    });

    expect(tx.pushDelivery.updateMany).toHaveBeenNthCalledWith(2, {
      where: {
        deviceId: existingDevice.id,
        status: 'SENT',
        acknowledgedAt: null,
        deliverySequence: {
          lte: 7n,
        },
        outbox: {
          eventType: 'ORDER_CREATED',
        },
      },
      data: {
        acknowledgedAt: expect.any(Date),
      },
    });
  });

  it('revokes only the current MANAGER installation on unregister', async () => {
    prisma.pushDevice.updateMany.mockResolvedValue({ count: 1 });

    await expect(
      service.unregister(manager, {
        installationId: 'install-12345678',
        appPackage: 'com.example.pharmaflow.dev',
      }),
    ).resolves.toEqual({ ok: true });

    expect(prisma.pushDevice.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          userId: manager.userId,
          installationId: 'install-12345678',
          appPackage: 'com.example.pharmaflow.dev',
          isEnabled: true,
        },
        data: expect.objectContaining({
          isEnabled: false,
          revokedAt: expect.any(Date),
          lastSeenAt: expect.any(Date),
        }),
      }),
    );
  });
});
