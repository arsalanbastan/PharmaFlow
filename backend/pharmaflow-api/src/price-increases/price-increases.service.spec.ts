import { BadRequestException, NotFoundException } from '@nestjs/common';
import { validate } from 'class-validator';
import {
  PriceIncreasesService,
  validateJalaliDate,
} from './price-increases.service';
import {
  CreatePriceIncreaseDto,
  PreparePriceAttachmentDto,
} from './price-increases.dto';
import type { AuthPrincipal } from '../auth/auth.types';

const actor: AuthPrincipal = {
  userId: 'b36c99fa-714b-4ab3-a36e-13632a32a398',
  username: 'staff',
  displayName: 'کارمند اول',
  role: 'STAFF',
  permissions: {
    canCreateOrders: true,
    managerAppAccess: false,
    canCreateCheques: false,
    canCreateCashPayments: false,
    canViewFinancialReports: false,
  },
};
const dto: CreatePriceIncreaseDto = {
  productName: '  آتورواستاتین 20  ',
  category: 'DRUG',
  newPrice: '123456.50',
  effectiveDate: '1405/08/18',
  source: ' اطلاعیه شرکت ',
  notes: 'توضیح',
};

describe('Price increases', () => {
  let tx: any,
    prisma: any,
    audit: any,
    storage: any,
    service: PriceIncreasesService;
  beforeEach(() => {
    tx = {
      priceIncrease: {
        create: jest
          .fn()
          .mockImplementation(async ({ data }) => ({ id: 'item', ...data })),
        findUnique: jest.fn().mockResolvedValue({ id: 'item' }),
        update: jest.fn().mockImplementation(async ({ data }) => ({ id: 'item', ...data })),
      },
      priceIncreaseConfirmation: {
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest
          .fn()
          .mockResolvedValue({
            userId: actor.userId,
            displayName: actor.displayName,
            confirmedAt: new Date('2026-11-09T10:00:00Z'),
          }),
      },
      priceIncreaseAttachment: {
        create: jest.fn(),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    prisma = {
      ...tx,
      $transaction: jest.fn(async (callback) =>
        typeof callback === 'function' ? callback(tx) : Promise.all(callback),
      ),
      priceIncreaseAttachment: { findFirst: jest.fn() },
    };
    audit = { record: jest.fn() };
    storage = {
      createUploadUrl: jest
        .fn()
        .mockResolvedValue({
          storageKey: 'price-increases/item/file.pdf',
          uploadUrl: 'signed',
        }),
      verifyUploadedObject: jest.fn(),
      createDownloadUrl: jest.fn(),
    };
    service = new PriceIncreasesService(prisma, audit, storage);
  });
  it('accepts Jalali leap day and rejects invalid calendar dates', () => {
    expect(validateJalaliDate('1403/12/30')).toBe('1403/12/30');
    for (const invalid of [
      '1404/12/30',
      '1405/07/31',
      '1405/00/10',
      '2026/11/09',
      '1405/13/01',
    ])
      expect(() => validateJalaliDate(invalid)).toThrow(BadRequestException);
  });
  it('creates a normalized product with authenticated actor and transactional audit', async () => {
    const result = await service.create(dto, { ...actor, role: 'MANAGER' });
    expect(result.createdByUserId).toBe(actor.userId);
    expect(result.productName).toBe('آتورواستاتین 20');
    expect(result.normalizedProductName).toContain('اتورواستاتین');
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'PRICE_INCREASE_CREATED' }),
      tx,
    );
  });
  it.each(['0', '-1', 'NaN', '1e10', '1.234', '10000000000000000'])(
    'rejects unsafe price %s',
    async (price) => {
      await expect(
        service.create({ ...dto, newPrice: price }, actor),
      ).rejects.toThrow(BadRequestException);
    },
  );
  it('records authenticated staff identity and never accepts a client timestamp', async () => {
    const result = await service.confirm('item', actor);
    expect(tx.priceIncreaseConfirmation.createMany).toHaveBeenCalledWith({
      data: [
        {
          priceIncreaseId: 'item',
          userId: actor.userId,
          displayName: actor.displayName,
        },
      ],
      skipDuplicates: true,
    });
    expect(result.confirmedAt.toISOString()).toBe('2026-11-09T10:00:00.000Z');
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'PRICE_INCREASE_CONFIRMED' }),
      tx,
    );
  });
  it('does not rewrite or audit an existing confirmation', async () => {
    tx.priceIncreaseConfirmation.createMany.mockResolvedValue({ count: 0 });
    await service.confirm('item', actor);
    expect(audit.record).not.toHaveBeenCalled();
  });
  it('rejects a confirmation for an unknown product', async () => {
    tx.priceIncrease.findUnique.mockResolvedValue(null);
    await expect(service.confirm('missing', actor)).rejects.toThrow(
      NotFoundException,
    );
    expect(tx.priceIncreaseConfirmation.createMany).not.toHaveBeenCalled();
  });
  it('scopes staff pending results to that employee and paginates', async () => {
    prisma.priceIncrease.findMany = jest.fn().mockResolvedValue([]);
    prisma.priceIncrease.count = jest.fn().mockResolvedValue(60);
    const result = await service.list({ status: 'PENDING', page: '2' }, actor);
    expect(prisma.priceIncrease.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { canceledAt: null, confirmations: { none: { userId: actor.userId } } },
        skip: 25,
        take: 25,
      }),
    );
    expect(result.total).toBe(60);
  });
  it('manager pending results reflect absence of any staff confirmation', async () => {
    prisma.priceIncrease.findMany = jest.fn().mockResolvedValue([]);
    prisma.priceIncrease.count = jest.fn().mockResolvedValue(0);
    await service.list({ status: 'PENDING' }, { ...actor, role: 'MANAGER' });
    expect(prisma.priceIncrease.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { canceledAt: null, confirmations: { none: {} } } }),
    );
  });
  it.each([
    { page: '0' },
    { page: '1.5' },
    { status: 'DELETED' },
    { category: 'ALL' },
    { from: '1405/12/01', to: '1405/01/01' },
  ])('rejects invalid history filter %j', async (query) => {
    await expect(service.list(query, actor)).rejects.toThrow(
      BadRequestException,
    );
  });
  it('allows manager editing only before staff confirmation', async () => {
    tx.priceIncrease.findUnique.mockResolvedValue({
      id: 'item', confirmations: [], canceledAt: null,
      productName: 'old',
    });
    const updated = await service.update('item', dto, { ...actor, role: 'MANAGER' });
    expect(updated.productName).toBe('آتورواستاتین 20');
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'PRICE_INCREASE_UPDATED' }), tx,
    );
    tx.priceIncrease.findUnique.mockResolvedValue({
      id: 'item', confirmations: [{ userId: actor.userId }], canceledAt: null,
    });
    await expect(service.update('item', dto, actor)).rejects.toThrow(BadRequestException);
  });
  it('cancels with a reason while preserving confirmations', async () => {
    tx.priceIncrease.findUnique.mockResolvedValue({ id: 'item', canceledAt: null });
    await service.cancel('item', { reason: 'اطلاعیه اصلاح شد' }, { ...actor, role: 'MANAGER' });
    expect(tx.priceIncrease.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          canceledByUserId: actor.userId,
          cancellationReason: 'اطلاعیه اصلاح شد',
        }),
      }),
    );
    expect(audit.record).toHaveBeenCalledWith(
      expect.objectContaining({ action: 'PRICE_INCREASE_CANCELED' }), tx,
    );
  });
  it('rejects confirmation for canceled instructions', async () => {
    tx.priceIncrease.findUnique.mockResolvedValue({ id: 'item', canceledAt: new Date() });
    await expect(service.confirm('item', actor)).rejects.toThrow(BadRequestException);
    expect(tx.priceIncreaseConfirmation.createMany).not.toHaveBeenCalled();
  });
  it('allows employees to confirm before the scheduled date', async () => {
    tx.priceIncrease.findUnique.mockResolvedValue({
      id: 'item', canceledAt: null, effectiveDate: '1406/12/29',
    });
    await expect(service.confirm('item', actor)).resolves.toBeDefined();
  });
  it('filters canceled records into their own history view', async () => {
    prisma.priceIncrease.findMany = jest.fn().mockResolvedValue([]);
    prisma.priceIncrease.count = jest.fn().mockResolvedValue(0);
    await service.list({ status: 'CANCELED' }, actor);
    expect(prisma.priceIncrease.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { canceledAt: { not: null } } }),
    );
  });
  it('does not confirm an attachment that failed storage verification', async () => {
    prisma.priceIncreaseAttachment.findFirst.mockResolvedValue({
      id: 'file',
      mimeType: 'application/pdf',
      fileSize: 123,
    });
    storage.verifyUploadedObject.mockRejectedValue(new BadRequestException());
    await expect(service.confirmAttachment('item', 'file')).rejects.toThrow(
      BadRequestException,
    );
    expect(tx.priceIncreaseAttachment.updateMany).not.toHaveBeenCalled();
  });
  it('does not expose a pending or foreign attachment', async () => {
    prisma.priceIncreaseAttachment.findFirst.mockResolvedValue(null);
    await expect(service.download('item', 'foreign')).rejects.toThrow(
      NotFoundException,
    );
    expect(storage.createDownloadUrl).not.toHaveBeenCalled();
  });
  it('validates file types, limits and spoofed DTO fields', async () => {
    const attachment = Object.assign(new PreparePriceAttachmentDto(), {
      fileName: 'a.pdf',
      mimeType: 'application/pdf',
      fileSize: 10 * 1024 * 1024 + 1,
    });
    expect((await validate(attachment)).length).toBeGreaterThan(0);
    attachment.fileSize = 1;
    attachment.mimeType = 'text/html';
    expect((await validate(attachment)).length).toBeGreaterThan(0);
    const create = Object.assign(new CreatePriceIncreaseDto(), dto, {
      createdByUserId: 'forged',
    });
    expect(
      (
        await validate(create, { whitelist: true, forbidNonWhitelisted: true })
      ).some((e) => e.property === 'createdByUserId'),
    ).toBe(true);
  });
});
