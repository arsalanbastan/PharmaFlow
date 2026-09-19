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

  function row(
    overrides: Record<string, unknown> = {},
  ) {
    return {
      id:
        '11111111-1111-4111-8111-111111111111',
      ingestSequence: 10n,
      arsenDrugId: 123n,
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
      ...overrides,
    };
  }

  it('returns paginated catalog rows without a search query', async () => {
    prisma.arsenCatalogItem.count
      .mockResolvedValue(1);

    prisma.arsenCatalogItem.findMany
      .mockResolvedValue([
        row({
          arsenDrugId: 123456789012345n,
        }),
      ]);

    const result =
      await service.findAll({
        category: 'DRUG',
        page: '1',
        pageSize: '50',
      });

    expect(result).toEqual({
      items: [
        expect.objectContaining({
          arsenDrugId:
            '123456789012345',
          category: 'DRUG',
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

  it('matches query words regardless of their order and ranks the closest match first', async () => {
    prisma.arsenCatalogItem.findMany
      .mockResolvedValue([
        row({
          id:
            '11111111-1111-4111-8111-111111111111',
          ingestSequence: 30n,
          persianName:
            'تونر ویتالایر پوست چرب',
          genericName:
            'تونر ویتالایر پوست چرب',
          brandName: 'VITALAYER',
        }),
        row({
          id:
            '22222222-2222-4222-8222-222222222222',
          ingestSequence: 20n,
          persianName:
            'ویتالایر تونر',
          genericName:
            'ویتالایر تونر',
          brandName: 'VITALAYER',
        }),
        row({
          id:
            '33333333-3333-4333-8333-333333333333',
          ingestSequence: 10n,
          persianName:
            'کرم ویتالایر',
          genericName:
            'کرم ویتالایر',
          brandName: 'VITALAYER',
        }),
      ]);

    const result =
      await service.findAll({
        q: 'ویتالایر تونر',
      });

    expect(result.totalCount).toBe(2);

    expect(result.items[0]).toEqual(
      expect.objectContaining({
        id:
          '22222222-2222-4222-8222-222222222222',
        persianName:
          'ویتالایر تونر',
      }),
    );

    expect(result.items[1]).toEqual(
      expect.objectContaining({
        id:
          '11111111-1111-4111-8111-111111111111',
        persianName:
          'تونر ویتالایر پوست چرب',
      }),
    );

    expect(
      prisma.arsenCatalogItem.count,
    ).not.toHaveBeenCalled();
  });

  it('requires every typed word to exist in the same catalog item', async () => {
    prisma.arsenCatalogItem.findMany
      .mockResolvedValue([
        row({
          id:
            '11111111-1111-4111-8111-111111111111',
          ingestSequence: 20n,
          persianName:
            'تونر ویتالایر پوست چرب',
          genericName:
            'تونر ویتالایر پوست چرب',
          brandName: 'VITALAYER',
        }),
        row({
          id:
            '22222222-2222-4222-8222-222222222222',
          ingestSequence: 10n,
          persianName:
            'تونر ویتالایر پوست خشک',
          genericName:
            'تونر ویتالایر پوست خشک',
          brandName: 'VITALAYER',
        }),
      ]);

    const result =
      await service.findAll({
        q: 'ویتالایر تونر خشک',
      });

    expect(result.totalCount).toBe(1);

    expect(result.items[0]).toEqual(
      expect.objectContaining({
        id:
          '22222222-2222-4222-8222-222222222222',
        persianName:
          'تونر ویتالایر پوست خشک',
      }),
    );
  });

  it('normalizes Arabic and Persian Yeh and Kaf during smart matching', async () => {
    prisma.arsenCatalogItem.findMany
      .mockResolvedValue([
        row({
          persianName:
            'تونر ويتالاير پوست چرب',
          genericName:
            'تونر ويتالاير پوست چرب',
        }),
      ]);

    const result =
      await service.findAll({
        q: 'ویتالایر تونر',
      });

    expect(result.totalCount).toBe(1);
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