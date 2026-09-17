import { BadRequestException, ForbiddenException } from '@nestjs/common';
import { createHash } from 'node:crypto';

import { OrdersService } from './orders.service';

describe('OrdersService race and photo cleanup', () => {
  const tx = {
    orderRequest: {
      create: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
      updateMany: jest.fn(),
    },
  };

  const prisma = {
    orderRequest: {
      findMany: jest.fn(),
      findUnique: jest.fn(),
      findFirst: jest.fn(),
      updateMany: jest.fn(),
    },
    company: {
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
    uploadBytes: jest.fn(),
    verifyUploadedObject: jest.fn(),
    createDownloadUrl: jest.fn(),
    deleteObject: jest.fn(),
  };

  const staffContext = {
    source: 'MOBILE_APP',
    actorDisplayName: 'امیر',
    actorUserId: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
    actorRole: 'STAFF',
    actorVerified: true,
  };

  const managerContext = {
    source: 'MOBILE_APP',
    actorDisplayName: 'ارسلان',
    actorUserId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
    actorRole: 'MANAGER',
    actorVerified: true,
  };

  const auditContext = {
    get: jest.fn(() => staffContext),
  };

  const pushOutbox = {
    enqueueOrderCreated: jest.fn(),
  };

  let service: OrdersService;
  let warnSpy: jest.SpyInstance;

  beforeAll(() => {
    warnSpy = jest.spyOn(console, 'warn').mockImplementation(() => undefined);
  });

  afterAll(() => {
    warnSpy.mockRestore();
  });

  beforeEach(() => {
    jest.clearAllMocks();

    auditContext.get.mockReturnValue(staffContext);
    tx.orderRequest.updateMany.mockResolvedValue({ count: 1 });
    prisma.orderRequest.updateMany.mockResolvedValue({ count: 1 });
    prisma.orderRequest.findUnique.mockResolvedValue(null);
    photoStorage.deleteObject.mockResolvedValue(undefined);
    photoStorage.uploadBytes.mockResolvedValue(
      'order-requests/555/request.jpg',
    );

    service = new OrdersService(
      prisma as never,
      auditLog as never,
      photoStorage as never,
      auditContext as never,
      pushOutbox as never,
    );
  });

  it('returns ranked active similarities with Persian normalization and typo tolerance', async () => {
    prisma.orderRequest.findMany.mockResolvedValue([
      {
        id: '11111111-1111-4111-8111-111111111111',
        itemText: 'آتورواستاتین 20',
        status: 'PENDING',
      },
      {
        id: '22222222-2222-4222-8222-222222222222',
        itemText: 'قرص آتورواستاتین 20',
        status: 'ORDERED',
      },
      {
        id: '33333333-3333-4333-8333-333333333333',
        itemText: 'قرص اتورواستاتین',
        status: 'PENDING',
      },
      {
        id: '44444444-4444-4444-8444-444444444444',
        itemText: 'آتروواستاتین',
        status: 'ORDERED',
      },
      {
        id: '55555555-5555-4555-8555-555555555555',
        itemText: 'آتورواستاتین 20',
        status: 'RECEIVED',
      },
      {
        id: '66666666-6666-4666-8666-666666666666',
        itemText: 'شامپو فولیکا',
        status: 'PENDING',
      },
    ]);

    const result = await service.checkDuplicate({
      category: 'DRUG',
      itemText: '  آتورواستاتین   ۲۰ ',
    });

    expect(result.found).toBe(true);
    expect(result.normalizedItemText).toBe('اتورواستاتین 20');
    expect(result.matches.map((match) => match.id)).toEqual([
      '11111111-1111-4111-8111-111111111111',
      '22222222-2222-4222-8222-222222222222',
      '33333333-3333-4333-8333-333333333333',
      '44444444-4444-4444-8444-444444444444',
    ]);
    expect(result.matches[0].similarityScore).toBe(1);

    expect(prisma.orderRequest.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          category: 'DRUG',
          status: {
            in: ['PENDING', 'ORDERED'],
          },
        },
      }),
    );
  });

  it('creates PENDING with verified requester name and user id', async () => {
    prisma.orderRequest.findMany.mockResolvedValue([]);

    tx.orderRequest.create.mockResolvedValue({
      id: '22222222-2222-4222-8222-222222222222',
      category: 'GOODS',
      itemText: 'شامپو فولیکا',
      normalizedItemText: 'شامپو فولیکا',
      status: 'PENDING',
      requestedByName: 'امیر',
      requestedByUserId: staffContext.actorUserId,
      possibleDuplicate: false,
    });

    const result = await service.create({
      category: 'GOODS',
      itemText: 'شامپو فولیکا',
    });

    expect(tx.orderRequest.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: 'PENDING',
          requestedByName: 'امیر',
          requestedByUserId: staffContext.actorUserId,
          possibleDuplicate: false,
        }),
      }),
    );

    expect(pushOutbox.enqueueOrderCreated).toHaveBeenCalledWith(
      expect.objectContaining({
        id: '22222222-2222-4222-8222-222222222222',
        itemText: 'شامپو فولیکا',
        requestedByName: 'امیر',
      }),
      tx,
    );

    expect(result.duplicateWarning.found).toBe(false);
  });

  it('returns all active requests to STAFF without requester filtering', async () => {
    prisma.orderRequest.findMany.mockResolvedValue([]);

    await service.findAll({});

    expect(prisma.orderRequest.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: {
            in: ['PENDING', 'ORDERED'],
          },
        }),
      }),
    );

    const call = prisma.orderRequest.findMany.mock.calls[0][0];

    expect(call.where).not.toHaveProperty('requestedByUserId');
  });

  it('does not expose inactive order history through the STAFF dashboard', async () => {
    await expect(
      service.findAll({ status: 'RECEIVED' }),
    ).rejects.toBeInstanceOf(ForbiddenException);

    expect(prisma.orderRequest.findMany).not.toHaveBeenCalled();
  });

  it('records the authenticated STAFF user when an ORDERED request arrives', async () => {
    const existing = {
      id: '77777777-7777-4777-8777-777777777777',
      status: 'ORDERED',
      itemText: 'آتورواستاتین 20',
    };

    const received = {
      ...existing,
      status: 'RECEIVED',
      receivedByName: staffContext.actorDisplayName,
      receivedByUserId: staffContext.actorUserId,
    };

    prisma.orderRequest.findFirst.mockResolvedValue(existing);
    tx.orderRequest.findUnique.mockResolvedValue(received);

    const result = await service.receive(existing.id);

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith({
      where: {
        id: existing.id,
        status: 'ORDERED',
      },
      data: expect.objectContaining({
        status: 'RECEIVED',
        receivedByName: staffContext.actorDisplayName,
        receivedByUserId: staffContext.actorUserId,
      }),
    });
    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        action: 'RECEIVE',
        entityId: existing.id,
        before: existing,
        after: received,
      }),
      tx,
    );
    expect(result).toBe(received);
  });

  it('assigns exactly once using a PENDING conditional update', async () => {
    auditContext.get.mockReturnValue(managerContext);

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'PENDING',
      requestedQuantity: 12,
      requestedByName: 'مریم',
      requestedByUserId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
      photoStorageKey: null,
    });

    prisma.company.findFirst.mockResolvedValue({
      id: '44444444-4444-4444-8444-444444444444',
      name: 'داروپخش',
    });

    tx.orderRequest.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'ORDERED',
      orderedQuantity: 12,
      orderedByName: 'ارسلان',
      orderedByUserId: managerContext.actorUserId,
    });

    await service.assign('33333333-3333-4333-8333-333333333333', {
      companyId: '44444444-4444-4444-8444-444444444444',
    });

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: '33333333-3333-4333-8333-333333333333',
          status: 'PENDING',
        },
        data: expect.objectContaining({
          status: 'ORDERED',
          orderedByUserId: managerContext.actorUserId,
        }),
      }),
    );
  });

  it('rejects the losing manager in a concurrent assignment race', async () => {
    auditContext.get.mockReturnValue(managerContext);

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'PENDING',
      requestedQuantity: 12,
      requestedByUserId: staffContext.actorUserId,
      photoStorageKey: null,
    });

    prisma.company.findFirst.mockResolvedValue({
      id: '44444444-4444-4444-8444-444444444444',
      name: 'داروپخش',
    });

    tx.orderRequest.updateMany.mockResolvedValue({ count: 0 });

    await expect(
      service.assign('33333333-3333-4333-8333-333333333333', {
        companyId: '44444444-4444-4444-8444-444444444444',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(auditLog.record).not.toHaveBeenCalled();
  });

  it('does not block assignment when S3 cleanup fails', async () => {
    auditContext.get.mockReturnValue(managerContext);

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'PENDING',
      requestedQuantity: 12,
      requestedByUserId: staffContext.actorUserId,
      photoStorageKey: 'order-requests/333/request.jpg',
    });

    prisma.company.findFirst.mockResolvedValue({
      id: '44444444-4444-4444-8444-444444444444',
      name: 'داروپخش',
    });

    tx.orderRequest.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'ORDERED',
      orderedByUserId: managerContext.actorUserId,
      photoStorageKey: 'order-requests/333/request.jpg',
      photoDeletedAt: null,
    });

    prisma.orderRequest.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'ORDERED',
      photoStorageKey: 'order-requests/333/request.jpg',
      photoDeletedAt: null,
    });

    photoStorage.deleteObject.mockRejectedValue(new Error('storage down'));

    await expect(
      service.assign('33333333-3333-4333-8333-333333333333', {
        companyId: '44444444-4444-4444-8444-444444444444',
      }),
    ).resolves.toEqual(
      expect.objectContaining({
        status: 'ORDERED',
      }),
    );

    expect(prisma.orderRequest.updateMany).not.toHaveBeenCalled();
  });

  it('clears photo metadata only after S3 deletion succeeds', async () => {
    auditContext.get.mockReturnValue(managerContext);

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'PENDING',
      requestedQuantity: 12,
      requestedByUserId: staffContext.actorUserId,
      photoStorageKey: 'order-requests/333/request.jpg',
    });

    prisma.company.findFirst.mockResolvedValue({
      id: '44444444-4444-4444-8444-444444444444',
      name: 'داروپخش',
    });

    tx.orderRequest.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'ORDERED',
      photoStorageKey: 'order-requests/333/request.jpg',
      photoDeletedAt: null,
    });

    prisma.orderRequest.findUnique.mockResolvedValue({
      id: '33333333-3333-4333-8333-333333333333',
      status: 'ORDERED',
      photoStorageKey: 'order-requests/333/request.jpg',
      photoDeletedAt: null,
    });

    await service.assign('33333333-3333-4333-8333-333333333333', {
      companyId: '44444444-4444-4444-8444-444444444444',
    });

    expect(photoStorage.deleteObject).toHaveBeenCalledWith(
      'order-requests/333/request.jpg',
    );

    expect(prisma.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: '33333333-3333-4333-8333-333333333333',
          photoStorageKey: 'order-requests/333/request.jpg',
          photoDeletedAt: null,
        }),
        data: expect.objectContaining({
          photoStorageKey: null,
          photoFileSize: null,
          photoSha256: null,
          photoDeletedAt: expect.any(Date),
        }),
      }),
    );
  });

  it('prevents confirm-vs-assign from attaching a photo after PENDING', async () => {
    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '55555555-5555-4555-8555-555555555555',
      status: 'PENDING',
      requestedByUserId: staffContext.actorUserId,
    });

    photoStorage.verifyUploadedObject.mockResolvedValue(
      'order-requests/555/request.jpg',
    );

    tx.orderRequest.updateMany.mockResolvedValue({ count: 0 });

    await expect(
      service.confirmPhotoUpload('55555555-5555-4555-8555-555555555555', {
        mimeType: 'image/jpeg',
        fileSize: 1000,
        sha256: 'a'.repeat(64),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(photoStorage.deleteObject).toHaveBeenCalledWith(
      'order-requests/555/request.jpg',
    );
  });

  it('confirms a photo with a conditional PENDING update', async () => {
    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '55555555-5555-4555-8555-555555555555',
      status: 'PENDING',
      requestedByUserId: staffContext.actorUserId,
    });

    photoStorage.verifyUploadedObject.mockResolvedValue(
      'order-requests/555/request.jpg',
    );

    tx.orderRequest.findUnique.mockResolvedValue({
      id: '55555555-5555-4555-8555-555555555555',
      status: 'PENDING',
      requestedByUserId: staffContext.actorUserId,
      photoStorageKey: 'order-requests/555/request.jpg',
    });

    const result = await service.confirmPhotoUpload(
      '55555555-5555-4555-8555-555555555555',
      {
        mimeType: 'image/jpeg',
        fileSize: 1000,
        sha256: 'b'.repeat(64),
      },
    );

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: '55555555-5555-4555-8555-555555555555',
          status: 'PENDING',
          requestedByUserId: staffContext.actorUserId,
        }),
      }),
    );

    expect(result.photoStorageKey).toBe('order-requests/555/request.jpg');
  });

  it('uploads a valid Staff PWA JPEG through the authenticated backend gateway', async () => {
    const orderId = '55555555-5555-4555-8555-555555555555';
    const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);
    const sha256 = createHash('sha256').update(bytes).digest('hex');

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: orderId,
      status: 'PENDING',
      requestedByUserId: staffContext.actorUserId,
    });

    tx.orderRequest.findUnique.mockResolvedValue({
      id: orderId,
      status: 'PENDING',
      requestedByUserId: staffContext.actorUserId,
      photoStorageKey: 'order-requests/555/request.jpg',
      photoFileSize: bytes.length,
      photoSha256: sha256,
    });

    const result = await service.uploadWebPhoto(orderId, {
      mimeType: 'image/jpeg',
      fileSize: bytes.length,
      sha256,
      imageBase64: bytes.toString('base64'),
    });

    expect(photoStorage.uploadBytes).toHaveBeenCalledWith(
      {
        orderId,
        mimeType: 'image/jpeg',
        fileSize: bytes.length,
      },
      bytes,
    );
    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: orderId,
          status: 'PENDING',
          requestedByUserId: staffContext.actorUserId,
        }),
        data: expect.objectContaining({
          photoFileSize: bytes.length,
          photoSha256: sha256,
        }),
      }),
    );
    expect(result.photoStorageKey).toBe('order-requests/555/request.jpg');
  });

  it('rejects a Staff PWA photo when its SHA256 is not valid', async () => {
    const orderId = '55555555-5555-4555-8555-555555555555';
    const bytes = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3, 4]);

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: orderId,
      status: 'PENDING',
      requestedByUserId: staffContext.actorUserId,
    });

    await expect(
      service.uploadWebPhoto(orderId, {
        mimeType: 'image/jpeg',
        fileSize: bytes.length,
        sha256: '0'.repeat(64),
        imageBase64: bytes.toString('base64'),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(photoStorage.uploadBytes).not.toHaveBeenCalled();
    expect(tx.orderRequest.updateMany).not.toHaveBeenCalled();
  });

  it('background retry includes RECEIVED and DELETED stale photos', async () => {
    prisma.orderRequest.findMany.mockResolvedValue([]);

    await (
      service as unknown as {
        retryPhotoCleanupBatch: () => Promise<void>;
      }
    ).retryPhotoCleanupBatch();

    expect(prisma.orderRequest.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          status: {
            in: expect.arrayContaining([
              'ORDERED',
              'RECEIVED',
              'CANCELED',
              'DELETED',
            ]),
          },
          photoStorageKey: {
            not: null,
          },
          photoDeletedAt: null,
        }),
        take: 50,
      }),
    );
  });

  it('allows STAFF to delete another users PENDING request', async () => {
    const existing = {
      id: '66666666-6666-4666-8666-666666666666',
      status: 'PENDING',
      requestedByUserId: 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
    };
    const deleted = {
      ...existing,
      status: 'DELETED',
      deletedByUserId: staffContext.actorUserId,
    };

    prisma.orderRequest.findFirst.mockResolvedValue(existing);
    tx.orderRequest.findUnique.mockResolvedValue(deleted);

    await expect(
      service.removePending('66666666-6666-4666-8666-666666666666'),
    ).resolves.toEqual(deleted);

    expect(tx.orderRequest.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: existing.id,
          status: 'PENDING',
        },
        data: expect.objectContaining({
          status: 'DELETED',
          deletedByUserId: staffContext.actorUserId,
        }),
      }),
    );
  });

  it('does not expose a photo after the order leaves PENDING', async () => {
    auditContext.get.mockReturnValue(managerContext);

    prisma.orderRequest.findFirst.mockResolvedValue({
      id: '99999999-9999-4999-8999-999999999999',
      status: 'ORDERED',
      requestedByUserId: staffContext.actorUserId,
      photoStorageKey: 'orders/photo.jpg',
    });

    await expect(
      service.createPhotoDownload('99999999-9999-4999-8999-999999999999'),
    ).rejects.toBeInstanceOf(Error);

    expect(photoStorage.createDownloadUrl).not.toHaveBeenCalled();
  });
});
