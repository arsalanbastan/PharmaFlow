import { BadRequestException, ForbiddenException } from '@nestjs/common';

import { OrdersService } from './orders.service';

describe('OrdersService canceled order restore and expiry', () => {
  const orderId = '44444444-4444-4444-8444-444444444444';

  const managerContext = {
    source: 'MOBILE_APP',
    actorDisplayName: 'مدیر',
    actorUserId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    actorRole: 'MANAGER',
    actorVerified: true,
  };

  const staffContext = {
    ...managerContext,
    actorRole: 'STAFF',
  };

  const pendingCanceled = {
    id: orderId,
    category: 'DRUG',
    itemText: 'داروی تست',
    normalizedItemText: 'داروی تست',
    requestedQuantity: 2,
    orderedQuantity: null,
    suggestedCompanyText: null,
    notes: null,
    status: 'CANCELED',
    assignedCompanyId: null,
    requestedByName: 'کاربر',
    requestedByUserId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    orderedByName: null,
    orderedByUserId: null,
    orderedAt: null,
    canceledAt: new Date(Date.now() - 60 * 60 * 1000),
    canceledByName: 'مدیر',
    canceledByUserId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    photoStorageKey: null,
  };

  const orderedCanceled = {
    ...pendingCanceled,
    orderedQuantity: 4,
    assignedCompanyId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    orderedByName: 'مدیر',
    orderedByUserId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    orderedAt: new Date(Date.now() - 2 * 60 * 60 * 1000),
  };

  const returnedPending = {
    ...pendingCanceled,
    status: 'PENDING',
    canceledAt: null,
    canceledByName: null,
    canceledByUserId: null,
    assignedCompany: null,
  };

  const returnedOrdered = {
    ...orderedCanceled,
    status: 'ORDERED',
    canceledAt: null,
    canceledByName: null,
    canceledByUserId: null,
    assignedCompany: {
      id: orderedCanceled.assignedCompanyId,
      name: 'شرکت تست',
    },
  };

  const tx = {
    orderRequest: {
      updateMany: jest.fn(),
      findUnique: jest.fn(),
    },
  };

  const prisma = {
    orderRequest: {
      findFirst: jest.fn(),
      findMany: jest.fn(),
    },
    $transaction: jest.fn(
      async (callback: (transaction: typeof tx) => Promise<unknown>) =>
        callback(tx),
    ),
  };

  const auditLog = {
    record: jest.fn(),
  };

  const photoStorage = {
    createUploadUrl: jest.fn(),
    verifyUploadedObject: jest.fn(),
    createDownloadUrl: jest.fn(),
    deleteObject: jest.fn(),
  };

  const auditContext = {
    get: jest.fn(() => managerContext),
  };

  const pushOutbox = {
    enqueueOrderCreated: jest.fn(),
  };

  let service: OrdersService;

  beforeEach(() => {
    jest.clearAllMocks();

    auditContext.get.mockReturnValue(managerContext);
    prisma.orderRequest.findFirst.mockResolvedValue(pendingCanceled);
    prisma.orderRequest.findMany.mockResolvedValue([]);
    tx.orderRequest.updateMany.mockResolvedValue({ count: 1 });
    tx.orderRequest.findUnique.mockResolvedValue(returnedPending);

    service = new OrdersService(
      prisma as never,
      auditLog as never,
      photoStorage as never,
      auditContext as never,
      pushOutbox as never,
    );
  });

  it('restores a canceled PENDING request back to PENDING', async () => {
    await service.restoreCanceled(orderId);

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith({
      where: {
        id: orderId,
        status: 'CANCELED',
      },
      data: {
        status: 'PENDING',
        canceledAt: null,
        canceledByName: null,
        canceledByUserId: null,
        assignedCompanyId: null,
        orderedQuantity: null,
        orderedAt: null,
        orderedByName: null,
        orderedByUserId: null,
      },
    });

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'ORDER_RESTORED_FROM_CANCELED',
        entityId: orderId,
      }),
      tx,
    );
  });

  it('restores a canceled ORDERED request back to ORDERED', async () => {
    prisma.orderRequest.findFirst.mockResolvedValue(orderedCanceled);
    tx.orderRequest.findUnique.mockResolvedValue(returnedOrdered);

    const result = await service.restoreCanceled(orderId);

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith({
      where: {
        id: orderId,
        status: 'CANCELED',
      },
      data: {
        status: 'ORDERED',
        canceledAt: null,
        canceledByName: null,
        canceledByUserId: null,
      },
    });

    expect(result).toEqual(returnedOrdered);
  });

  it('does not allow restore after the 72-hour window', async () => {
    prisma.orderRequest.findFirst.mockResolvedValue({
      ...pendingCanceled,
      canceledAt: new Date(Date.now() - 73 * 60 * 60 * 1000),
    });

    await expect(service.restoreCanceled(orderId)).rejects.toBeInstanceOf(
      BadRequestException,
    );

    expect(tx.orderRequest.updateMany).not.toHaveBeenCalled();
  });

  it('rejects restore by STAFF', async () => {
    auditContext.get.mockReturnValue(staffContext);

    await expect(service.restoreCanceled(orderId)).rejects.toBeInstanceOf(
      ForbiddenException,
    );

    expect(prisma.orderRequest.findFirst).not.toHaveBeenCalled();
  });

  it('soft-deletes canceled orders after 72 hours', async () => {
    const now = new Date('2026-09-03T08:00:00.000Z');
    const stale = {
      ...pendingCanceled,
      canceledAt: new Date('2026-08-30T08:00:00.000Z'),
    };

    const deleted = {
      ...stale,
      status: 'DELETED',
      deletedAt: now,
      deletedByName: 'SYSTEM',
      deletedByUserId: null,
    };

    prisma.orderRequest.findMany.mockResolvedValue([stale]);
    tx.orderRequest.findUnique.mockResolvedValue(deleted);

    const count = await service.expireCanceledOrdersBatch(now);

    expect(count).toBe(1);

    expect(prisma.orderRequest.findMany).toHaveBeenCalledWith({
      where: {
        status: 'CANCELED',
        canceledAt: {
          lte: new Date('2026-08-31T08:00:00.000Z'),
        },
      },
      orderBy: [
        {
          canceledAt: 'asc',
        },
        {
          id: 'asc',
        },
      ],
      take: 100,
    });

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith({
      where: {
        id: orderId,
        status: 'CANCELED',
        canceledAt: {
          lte: new Date('2026-08-31T08:00:00.000Z'),
        },
      },
      data: {
        status: 'DELETED',
        deletedAt: now,
        deletedByName: 'SYSTEM',
        deletedByUserId: null,
      },
    });

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'AUTO_DELETE_CANCELED_ORDER',
        entityId: orderId,
      }),
      tx,
    );
  });
});