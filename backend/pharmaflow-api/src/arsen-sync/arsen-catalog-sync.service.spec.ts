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
