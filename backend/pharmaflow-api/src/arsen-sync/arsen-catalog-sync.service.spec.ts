import { BadRequestException } from '@nestjs/common';

import { ArsenSyncService } from './arsen-sync.service';
import { ArsenCatalogItemDto } from './dto/arsen-catalog-item.dto';

describe('Arsen catalog item sync', () => {
  function item(
    overrides: Partial<ArsenCatalogItemDto> = {},
  ): ArsenCatalogItemDto {
    return {
      arsenDrugId: '127963',
      isDrug: true,
      persianName: 'بیلی کات',
      genericName: 'BILI-CUT',
      persianBrandName: null,
      brandName: null,
      unit: null,
      shapeName: 'Drop',
      packetQuantity: 1,
      salesPrice: '100000.0000',
      lastPurchasePrice: '80000.0000',
      isActive: true,
      barcodes: [],
      description: null,
      ...overrides,
    };
  }

  it('rejects duplicate arsenDrugId values before writing', async () => {
    const prisma = {
      arsenCatalogItem: {
        findMany: jest.fn(),
      },
    };

    const service = new ArsenSyncService(prisma as never, {} as never);

    await expect(
      service.ingestCatalogItems([
        item({ arsenDrugId: '127963' }),
        item({ arsenDrugId: '127963' }),
      ]),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(prisma.arsenCatalogItem.findMany).not.toHaveBeenCalled();
  });

  it('creates once and classifies an identical retry as unchanged', async () => {
    let persisted:
      | {
          id: string;
          arsenDrugId: bigint;
          category: string;
          sourceFingerprint: string;
        }
      | undefined;

    const tx = {
      arsenCatalogItem: {
        upsert: jest.fn().mockImplementation(({ create }) => {
          persisted = {
            id: '11111111-1111-4111-8111-111111111111',
            arsenDrugId: create.arsenDrugId,
            category: create.category,
            sourceFingerprint: create.sourceFingerprint,
          };

          return Promise.resolve({ id: persisted.id });
        }),
      },
      arsenCatalogBarcode: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      auditLog: {
        create: jest.fn().mockResolvedValue({}),
      },
    };

    const prisma = {
      arsenCatalogItem: {
        findMany: jest.fn().mockImplementation(() =>
          Promise.resolve(persisted ? [persisted] : []),
        ),
      },
      $transaction: jest.fn().mockImplementation(
        async (callback: (client: typeof tx) => unknown) => callback(tx),
      ),
    };

    const auditLog = {
      record: jest.fn().mockResolvedValue({}),
    };

    const service = new ArsenSyncService(prisma as never, auditLog as never);

    const first = await service.ingestCatalogItems([item()]);
    const second = await service.ingestCatalogItems([item()]);

    expect(first).toEqual(
      expect.objectContaining({
        processed: 1,
        created: 1,
        updated: 0,
        unchanged: 0,
      }),
    );

    expect(second).toEqual(
      expect.objectContaining({
        processed: 1,
        created: 0,
        updated: 0,
        unchanged: 1,
      }),
    );

    expect(tx.arsenCatalogItem.upsert).toHaveBeenCalledTimes(1);
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    expect(auditLog.record).toHaveBeenCalledTimes(1);
  });

  it('stores every authoritative barcode for a catalog item with a normalized lookup key', async () => {
    const tx = {
      arsenCatalogItem: {
        upsert: jest.fn().mockResolvedValue({
          id: '11111111-1111-4111-8111-111111111111',
        }),
      },
      arsenCatalogBarcode: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 2 }),
      },
      auditLog: {
        create: jest.fn().mockResolvedValue({}),
      },
    };
    const prisma = {
      arsenCatalogItem: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      $transaction: jest.fn().mockImplementation(
        async (callback: (client: typeof tx) => unknown) => callback(tx),
      ),
    };
    const auditLog = { record: jest.fn().mockResolvedValue({}) };
    const service = new ArsenSyncService(prisma as never, auditLog as never);

    await service.ingestCatalogItems([
      item({
        barcodes: [
          {
            arsenBarcodeId: '44160',
            barcode: '000006267429502049',
            barcodeNormalized: '000006267429502049',
            defQnt: 1,
          },
          {
            arsenBarcodeId: '48099',
            barcode: '000006267429502582',
            barcodeNormalized: '000006267429502582',
            defQnt: 1,
          },
        ],
      }),
    ]);

    expect(tx.arsenCatalogBarcode.deleteMany).toHaveBeenCalledWith({
      where: {
        OR: expect.arrayContaining([
          {
            catalogItemId: {
              in: ['11111111-1111-4111-8111-111111111111'],
            },
          },
          { lookupKey: { in: ['6267429502049', '6267429502582'] } },
          { arsenBarcodeId: { in: [44160n, 48099n] } },
        ]),
      },
    });
    expect(tx.arsenCatalogBarcode.createMany).toHaveBeenCalledWith({
      data: expect.arrayContaining([
        expect.objectContaining({
          arsenBarcodeId: 44160n,
          barcode: '000006267429502049',
          barcodeNormalized: '000006267429502049',
          lookupKey: '6267429502049',
          defQnt: 1,
        }),
        expect.objectContaining({
          arsenBarcodeId: 48099n,
          lookupKey: '6267429502582',
        }),
      ]),
    });
  });

  it('preserves existing barcodes when a legacy bridge omits the barcodes property', async () => {
    const existingBarcode = {
      arsenBarcodeId: 44160n,
      barcode: '000006267429502049',
      barcodeNormalized: '000006267429502049',
      lookupKey: '6267429502049',
      defQnt: 1,
    };
    const tx = {
      arsenCatalogItem: {
        upsert: jest.fn().mockResolvedValue({
          id: '11111111-1111-4111-8111-111111111111',
        }),
      },
      arsenCatalogBarcode: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      auditLog: { create: jest.fn().mockResolvedValue({}) },
    };
    const prisma = {
      arsenCatalogItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: '11111111-1111-4111-8111-111111111111',
            arsenDrugId: 127963n,
            category: 'DRUG',
            sourceFingerprint: 'legacy-fingerprint',
            barcodes: [existingBarcode],
          },
        ]),
      },
      $transaction: jest.fn().mockImplementation(
        async (callback: (client: typeof tx) => unknown) => callback(tx),
      ),
    };
    const auditLog = { record: jest.fn().mockResolvedValue({}) };
    const service = new ArsenSyncService(prisma as never, auditLog as never);

    await service.ingestCatalogItems([
      item({ barcodes: undefined, salesPrice: '100001.0000' }),
    ]);

    expect(tx.arsenCatalogBarcode.deleteMany).not.toHaveBeenCalled();
    expect(tx.arsenCatalogBarcode.createMany).not.toHaveBeenCalled();
    expect(auditLog.record).toHaveBeenCalledWith(
      expect.objectContaining({
        after: expect.objectContaining({
          barcodes: [
            expect.objectContaining({
              arsenBarcodeId: '44160',
              lookupKey: '6267429502049',
            }),
          ],
        }),
      }),
      tx,
    );
  });

  it('rejects one barcode assigned to multiple DrugIDs in the same batch', async () => {
    const prisma = {
      arsenCatalogItem: { findMany: jest.fn() },
    };
    const service = new ArsenSyncService(prisma as never, {} as never);

    await expect(
      service.ingestCatalogItems([
        item({
          arsenDrugId: '1',
          barcodes: [
            {
              arsenBarcodeId: '10',
              barcode: '000006267429502049',
              barcodeNormalized: '000006267429502049',
              defQnt: 1,
            },
          ],
        }),
        item({
          arsenDrugId: '2',
          barcodes: [
            {
              arsenBarcodeId: '11',
              barcode: '6267429502049',
              barcodeNormalized: '000006267429502049',
              defQnt: 1,
            },
          ],
        }),
      ]),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(prisma.arsenCatalogItem.findMany).not.toHaveBeenCalled();
  });

  it('maps isDrug to the explicit DRUG/GOODS category', async () => {
    const creates: Array<{ category: string }> = [];

    const tx = {
      arsenCatalogItem: {
        upsert: jest.fn().mockImplementation(({ create }) => {
          creates.push(create);
          return Promise.resolve({
            id: `11111111-1111-4111-8111-${String(creates.length).padStart(12, '0')}`,
          });
        }),
      },
      arsenCatalogBarcode: {
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        createMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      auditLog: {
        create: jest.fn().mockResolvedValue({}),
      },
    };

    const prisma = {
      arsenCatalogItem: {
        findMany: jest.fn().mockResolvedValue([]),
      },
      $transaction: jest.fn().mockImplementation(
        async (callback: (client: typeof tx) => unknown) => callback(tx),
      ),
    };

    const auditLog = {
      record: jest.fn().mockResolvedValue({}),
    };

    const service = new ArsenSyncService(prisma as never, auditLog as never);

    await service.ingestCatalogItems([
      item({ arsenDrugId: '1', isDrug: true }),
      item({ arsenDrugId: '2', isDrug: false }),
    ]);

    expect(creates.map((entry) => entry.category)).toEqual(['DRUG', 'GOODS']);
  });
});
