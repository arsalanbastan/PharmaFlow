import { BadRequestException, ForbiddenException } from '@nestjs/common';

import { OrdersService } from './orders.service';

describe('OrdersService return ORDERED to PENDING', () => {
  const orderId = '33333333-3333-4333-8333-333333333333';

  const existingOrdered = {
    id: orderId,
    category: 'DRUG',
    itemText: 'آتورواستاتین 20',
    normalizedItemText: 'اتورواستاتین 20',
    requestedQuantity: 2,
    orderedQuantity: 5,
    suggestedCompanyText: 'شرکت پیشنهادی',
    notes: 'یادداشت درخواست',
    status: 'ORDERED',
    assignedCompanyId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    requestedByName: 'امیر',
    requestedByUserId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    orderedByName: 'مدیر',
    orderedByUserId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
    orderedAt: new Date('2026-08-19T08:00:00.000Z'),
    photoStorageKey: null,
  };

  const returnedPending = {
    ...existingOrdered,
    orderedQuantity: null,
    status: 'PENDING',
    assignedCompanyId: null,
    assignedCompany: null,
    orderedByName: null,
    orderedByUserId: null,
    orderedAt: null,
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
    prisma.orderRequest.findFirst.mockResolvedValue(existingOrdered);
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

  it('clears assignment metadata while preserving the original request', async () => {
    const result = await service.returnToPending(orderId);

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith({
      where: {
        id: orderId,
        status: 'ORDERED',
      },
      data: {
        status: 'PENDING',
        assignedCompanyId: null,
        orderedQuantity: null,
        orderedAt: null,
        orderedByName: null,
        orderedByUserId: null,
      },
    });

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'ORDER_RETURNED_TO_PENDING',
        entityType: 'ORDER_REQUEST',
        entityId: orderId,
        before: existingOrdered,
        after: returnedPending,
      }),
      tx,
    );

    expect(result).toEqual(returnedPending);
    expect(result.itemText).toBe(existingOrdered.itemText);
    expect(result.requestedQuantity).toBe(existingOrdered.requestedQuantity);
    expect(result.suggestedCompanyText).toBe(
      existingOrdered.suggestedCompanyText,
    );
    expect(result.notes).toBe(existingOrdered.notes);
  });

  it('rejects a non-ORDERED order before mutation', async () => {
    prisma.orderRequest.findFirst.mockResolvedValue({
      ...existingOrdered,
      status: 'PENDING',
    });

    await expect(service.returnToPending(orderId)).rejects.toBeInstanceOf(
      BadRequestException,
    );

    expect(tx.orderRequest.updateMany).not.toHaveBeenCalled();
    expect(auditLog.record).not.toHaveBeenCalled();
  });

  it('rejects a STAFF actor before reading or mutating the order', async () => {
    auditContext.get.mockReturnValue(staffContext);

    await expect(service.returnToPending(orderId)).rejects.toBeInstanceOf(
      ForbiddenException,
    );

    expect(prisma.orderRequest.findFirst).not.toHaveBeenCalled();
    expect(tx.orderRequest.updateMany).not.toHaveBeenCalled();
    expect(auditLog.record).not.toHaveBeenCalled();
  });

  it('rejects a concurrent status change and writes no audit event', async () => {
    tx.orderRequest.updateMany.mockResolvedValue({ count: 0 });

    await expect(service.returnToPending(orderId)).rejects.toBeInstanceOf(
      BadRequestException,
    );

    expect(auditLog.record).not.toHaveBeenCalled();
  });
});
