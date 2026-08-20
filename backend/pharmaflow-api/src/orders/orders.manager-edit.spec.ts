import { BadRequestException } from '@nestjs/common';

import { OrdersService } from './orders.service';

describe('OrdersService manager pending edit', () => {
  const existingPending = {
    id: '33333333-3333-4333-8333-333333333333',
    category: 'DRUG',
    itemText: 'آتورواستاتین 20',
    normalizedItemText: 'آتورواستاتین 20',
    requestedQuantity: 2,
    suggestedCompanyText: null,
    notes: null,
    status: 'PENDING',
    requestedByName: 'امیر',
    requestedByUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    photoStorageKey: null,
  };

  const updatedPending = {
    ...existingPending,
    category: 'GOODS',
    itemText: 'شامپو تست',
    normalizedItemText: 'شامپو تست',
    requestedQuantity: 4,
    suggestedCompanyText: 'شرکت تست',
    notes: 'یادداشت جدید',
    possibleDuplicate: false,
  };

  const tx = {
    orderRequest: {
      findUnique: jest.fn(),
      updateMany: jest.fn(),
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

  const managerContext = {
    source: 'MOBILE_APP',
    actorDisplayName: 'مدیر',
    actorUserId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    actorRole: 'MANAGER',
    actorVerified: true,
  };

  const staffContext = {
    ...managerContext,
    actorRole: 'STAFF',
  };

  const requesterStaffContext = {
    ...staffContext,
    actorDisplayName: existingPending.requestedByName,
    actorUserId: existingPending.requestedByUserId,
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
    prisma.orderRequest.findFirst.mockResolvedValue(existingPending);
    prisma.orderRequest.findMany.mockResolvedValue([]);
    tx.orderRequest.updateMany.mockResolvedValue({ count: 1 });
    tx.orderRequest.findUnique
      .mockResolvedValueOnce(existingPending)
      .mockResolvedValueOnce(updatedPending);

    service = new OrdersService(
      prisma as never,
      auditLog as never,
      photoStorage as never,
      auditContext as never,
      pushOutbox as never,
    );
  });

  it('updates all editable PENDING fields and records an audit event', async () => {
    const result = await service.updatePending(existingPending.id, {
      category: 'GOODS',
      itemText: '  شامپو تست  ',
      requestedQuantity: 4,
      suggestedCompanyText: ' شرکت تست ',
      notes: ' یادداشت جدید ',
    });

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith({
      where: {
        id: existingPending.id,
        status: 'PENDING',
      },
      data: {
        category: 'GOODS',
        itemText: 'شامپو تست',
        normalizedItemText: 'شامپو تست',
        requestedQuantity: 4,
        suggestedCompanyText: 'شرکت تست',
        notes: 'یادداشت جدید',
        possibleDuplicate: false,
      },
    });

    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'ORDER_UPDATED',
        entityType: 'ORDER_REQUEST',
        entityId: existingPending.id,
      }),
      tx,
    );

    expect(result).toEqual(updatedPending);
  });

  it('rejects editing a non-PENDING order', async () => {
    prisma.orderRequest.findFirst.mockResolvedValue({
      ...existingPending,
      status: 'ORDERED',
    });

    await expect(
      service.updatePending(existingPending.id, {
        category: 'DRUG',
        itemText: 'آتورواستاتین 20',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('allows a STAFF actor to edit another users PENDING order', async () => {
    auditContext.get.mockReturnValue(staffContext);

    await service.updatePending(existingPending.id, {
      category: 'DRUG',
      itemText: 'آتورواستاتین 20',
    });

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: existingPending.id,
          status: 'PENDING',
        },
      }),
    );
  });

  it('allows the original STAFF requester to edit while still PENDING', async () => {
    auditContext.get.mockReturnValue(requesterStaffContext);

    await service.updatePending(existingPending.id, {
      category: 'GOODS',
      itemText: 'شامپو تست',
      requestedQuantity: 4,
      suggestedCompanyText: 'شرکت تست',
      notes: 'یادداشت جدید',
    });

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: existingPending.id,
          status: 'PENDING',
        },
      }),
    );
  });
});
