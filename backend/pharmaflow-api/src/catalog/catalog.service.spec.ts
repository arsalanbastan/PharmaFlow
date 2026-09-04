import {
  BadRequestException,
  NotFoundException,
} from '@nestjs/common';

import { CatalogService } from './catalog.service';

describe('CatalogService', () => {
  const prisma = {
    arsenCatalogItem: {
      count: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
    },
  };

  let service: CatalogService;

  beforeEach(() => {
    jest.clearAllMocks();

    service =
      new CatalogService(prisma as never);
  });

  it('returns paginated catalog rows and serializes BigInt ids', async () => {
    prisma.arsenCatalogItem.count
      .mockResolvedValue(1);

    prisma.arsenCatalogItem.findMany
      .mockResolvedValue([
        {
          id:
            '11111111-1111-4111-8111-111111111111',
          arsenDrugId: 123456789012345n,
          category: 'DRUG',
          persianName: 'داروی تست',
          genericName: 'TEST GENERIC',
          persianBrandName: null,
          brandName: 'TEST BRAND',
          unit: 'عدد',
          shapeName: 'قرص',
          packetQuantity: 20,
          salesPrice: '250000',
          lastPurchasePrice: '180000',
          isActive: true,
          sourceSyncedAt:
            new Date('2026-09-04T10:00:00Z'),
        },
      ]);

    const result =
      await service.findAll({
        q: 'داروی تست',
        category: 'DRUG',
        page: '1',
        pageSize: '50',
      });

    expect(result).toEqual({
      items: [
        expect.objectContaining({
          arsenDrugId: '123456789012345',
          category: 'DRUG',
          persianName: 'داروی تست',
          salesPrice: '250000',
          lastPurchasePrice: '180000',
          isActive: true,
        }),
      ],
      page: 1,
      pageSize: 50,
      totalCount: 1,
      totalPages: 1,
    });

    expect(
      prisma.arsenCatalogItem.findMany,
    ).toHaveBeenCalledWith(
      expect.objectContaining({
        orderBy: {
          ingestSequence: 'desc',
        },
        skip: 0,
        take: 50,
      }),
    );
  });

  it('rejects an invalid category', async () => {
    await expect(
      service.findAll({
        category: 'INVALID',
      }),
    ).rejects.toBeInstanceOf(
      BadRequestException,
    );

    expect(
      prisma.arsenCatalogItem.count,
    ).not.toHaveBeenCalled();
  });

  it('returns full catalog item details', async () => {
    prisma.arsenCatalogItem.findUnique
      .mockResolvedValue({
        id:
          '11111111-1111-4111-8111-111111111111',
        ingestSequence: 10n,
        arsenDrugId: 123n,
        category: 'GOODS',
        persianName: 'کالای تست',
        genericName: null,
        persianBrandName: 'برند تست',
        brandName: null,
        unit: 'عدد',
        shapeName: null,
        packetQuantity: 1,
        salesPrice: '100000',
        lastPurchasePrice: '80000',
        isActive: true,
        description: 'توضیحات تست',
        sourceFingerprint: 'abc',
        importedAt:
          new Date('2026-09-01T10:00:00Z'),
        sourceSyncedAt:
          new Date('2026-09-04T10:00:00Z'),
        createdAt:
          new Date('2026-09-01T10:00:00Z'),
        updatedAt:
          new Date('2026-09-04T10:00:00Z'),
      });

    const result =
      await service.findOne(
        '11111111-1111-4111-8111-111111111111',
      );

    expect(result).toEqual(
      expect.objectContaining({
        arsenDrugId: '123',
        category: 'GOODS',
        persianName: 'کالای تست',
        description: 'توضیحات تست',
      }),
    );
  });

  it('returns 404 for a missing catalog item', async () => {
    prisma.arsenCatalogItem.findUnique
      .mockResolvedValue(null);

    await expect(
      service.findOne(
        '11111111-1111-4111-8111-111111111111',
      ),
    ).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});