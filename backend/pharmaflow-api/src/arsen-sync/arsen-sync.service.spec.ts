import { BadRequestException } from '@nestjs/common';

import { ArsenSyncService } from './arsen-sync.service';
import { ArsenInvoiceDto } from './dto/arsen-invoice.dto';

describe('ArsenSyncService', () => {
  function invoice(overrides: Partial<ArsenInvoiceDto> = {}): ArsenInvoiceDto {
    return {
      arsenFactorId: 16639,
      invoiceNumber: 'TEST-1',
      invoiceDate: '1405/06/05',
      settlementDate: '1405/08/04',
      description: 'توضیح تست',
      factorDocType: 1,
      arsenBusinessPartnerId: 526,
      arsenBusinessPartnerName: 'هجرت',
      factorPayablePrice: '123456.0000',
      isDeletedInArsen: false,
      items: [
        {
          arsenFactorDetailId: '50001',
          arsenFactorDetailsId: 1,
          arsenDrugId: '1001',
          drugName: 'داروی تست',
          quantity: 2,
          purchasePrice: '100.0000',
        },
      ],
      ...overrides,
    };
  }

  it('creates and maps a new Arsen company before invoice ingestion', async () => {
    const tx = {
      arsenCompanyMapping: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'mapping-id' }),
      },
      company: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'company-id',
          deletedAt: null,
        }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    };
    const prisma = {
      $transaction: jest.fn().mockImplementation(
        async (callback: (arg: typeof tx) => unknown) => callback(tx),
      ),
    };
    const auditLog = { record: jest.fn().mockResolvedValue({}) };
    const service = new ArsenSyncService(prisma as never, auditLog as never);

    const result = await service.ingestCompanies([
      { arsenBusinessPartnerId: 999, arsenName: 'شرکت جدید' },
    ]);

    expect(result).toMatchObject({ processed: 1, created: 1 });
    expect(tx.company.create).toHaveBeenCalledWith({
      data: { name: 'شرکت جدید' },
      select: { id: true, deletedAt: true },
    });
    expect(tx.arsenCompanyMapping.create).toHaveBeenCalledWith({
      data: {
        arsenBusinessPartnerId: 999,
        arsenName: 'شرکت جدید',
        companyId: 'company-id',
      },
      select: { id: true },
    });
  });

  it('keeps an existing active company mapping unchanged', async () => {
    const tx = {
      arsenCompanyMapping: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'mapping-id',
          arsenName: 'هجرت',
          companyId: 'company-id',
          company: { deletedAt: null },
        }),
        update: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest
        .fn()
        .mockImplementation(async (callback: (arg: typeof tx) => unknown) =>
          callback(tx),
        ),
    };
    const service = new ArsenSyncService(prisma as never, {} as never);

    const result = await service.ingestCompanies([
      { arsenBusinessPartnerId: 526, arsenName: 'هجرت' },
    ]);

    expect(result).toMatchObject({ processed: 1, unchanged: 1 });
    expect(tx.arsenCompanyMapping.update).not.toHaveBeenCalled();
  });

  it('rejects an unmapped supplier before writing', async () => {
    const prisma = {
      arsenCompanyMapping: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    const service = new ArsenSyncService(prisma as never, {} as never);

    await expect(service.ingest([invoice()])).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('does not rewrite an unchanged invoice', async () => {
    let persistedFingerprint = '';
    const tx = {
      arsenInvoice: {
        upsert: jest.fn().mockImplementation(({ create }) => {
          persistedFingerprint = create.sourceFingerprint;
          return Promise.resolve({ id: 'invoice-id' });
        }),
      },
      arsenInvoiceItem: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    };
    const prisma = {
      arsenCompanyMapping: {
        findUnique: jest.fn().mockResolvedValue({
          companyId: '11111111-1111-4111-8111-111111111111',
          company: { deletedAt: null },
        }),
      },
      arsenInvoice: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(null)
          .mockImplementationOnce(() =>
            Promise.resolve({
              id: 'invoice-id',
              companyId: '11111111-1111-4111-8111-111111111111',
              sourceFingerprint: persistedFingerprint,
              invoiceNumber: 'TEST-1',
              invoiceDate: '1405/06/05',
              settlementDate: '1405/08/04',
              description: 'توضیح تست',
              factorPayablePrice: '123456.0000',
              itemCount: 1,
              isDeletedInArsen: false,
            }),
          ),
      },
      $transaction: jest.fn().mockImplementation(
        async (callback: (arg: typeof tx) => unknown) => callback(tx),
      ),
    };
    const auditLog = { record: jest.fn().mockResolvedValue({}) };
    const service = new ArsenSyncService(prisma as never, auditLog as never);

    const first = await service.ingest([invoice()]);
    const second = await service.ingest([invoice()]);

    expect(first.created).toBe(1);
    expect(tx.arsenInvoice.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({
          settlementDate: '1405/08/04',
          description: 'توضیح تست',
        }),
      }),
    );
    expect(second.unchanged).toBe(1);
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(auditLog.record).toHaveBeenCalledTimes(1);
  });

  it('rejects duplicate detail IDs inside one invoice', async () => {
    const prisma = {
      arsenCompanyMapping: { findUnique: jest.fn() },
    };
    const service = new ArsenSyncService(prisma as never, {} as never);
    const payload = invoice({
      items: [
        { arsenFactorDetailId: '1' },
        { arsenFactorDetailId: '1' },
      ],
    });

    await expect(service.ingest([payload])).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.arsenCompanyMapping.findUnique).not.toHaveBeenCalled();
  });
});
