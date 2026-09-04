import type { Prisma } from '@prisma/client';
import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../database/prisma/prisma.service';

type CatalogFilters = {
  q?: string;
  category?: string;
  active?: string;
  page?: string;
  pageSize?: string;
};

const DEFAULT_PAGE_SIZE = 50;
const ALLOWED_PAGE_SIZES = new Set([25, 50, 100]);

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(filters: CatalogFilters = {}) {
    const where = this.buildWhere(filters);

    const requestedPage =
      this.readPositiveInteger(filters.page, 'page') ?? 1;

    const pageSize = this.readPageSize(filters.pageSize);

    const totalCount =
      await this.prisma.arsenCatalogItem.count({
        where,
      });

    const totalPages =
      Math.max(1, Math.ceil(totalCount / pageSize));

    const page =
      Math.min(requestedPage, totalPages);

    const skip =
      (page - 1) * pageSize;

    const rows =
      await this.prisma.arsenCatalogItem.findMany({
        where,
        select: {
          id: true,
          arsenDrugId: true,
          category: true,
          persianName: true,
          genericName: true,
          persianBrandName: true,
          brandName: true,
          unit: true,
          shapeName: true,
          packetQuantity: true,
          salesPrice: true,
          lastPurchasePrice: true,
          isActive: true,
          sourceSyncedAt: true,
        },
        orderBy: {
          ingestSequence: 'desc',
        },
        skip,
        take: pageSize,
      });

    return {
      items: rows.map((row) => ({
        id: row.id,
        arsenDrugId: row.arsenDrugId.toString(),
        category: row.category,
        persianName: row.persianName,
        genericName: row.genericName,
        persianBrandName: row.persianBrandName,
        brandName: row.brandName,
        unit: row.unit,
        shapeName: row.shapeName,
        packetQuantity: row.packetQuantity,
        salesPrice: this.decimalString(row.salesPrice),
        lastPurchasePrice:
          this.decimalString(row.lastPurchasePrice),
        isActive: row.isActive,
        sourceSyncedAt:
          row.sourceSyncedAt.toISOString(),
      })),
      page,
      pageSize,
      totalCount,
      totalPages,
    };
  }

  async findOne(id: string) {
    const normalizedId = id.trim();

    if (!UUID_PATTERN.test(normalizedId)) {
      throw new BadRequestException(
        'Invalid catalog item id.',
      );
    }

    const item =
      await this.prisma.arsenCatalogItem.findUnique({
        where: {
          id: normalizedId,
        },
      });

    if (item == null) {
      throw new NotFoundException(
        'Catalog item not found.',
      );
    }

    return {
      id: item.id,
      arsenDrugId: item.arsenDrugId.toString(),
      category: item.category,

      persianName: item.persianName,
      genericName: item.genericName,
      persianBrandName: item.persianBrandName,
      brandName: item.brandName,

      unit: item.unit,
      shapeName: item.shapeName,

      packetQuantity: item.packetQuantity,
      salesPrice:
        this.decimalString(item.salesPrice),
      lastPurchasePrice:
        this.decimalString(
          item.lastPurchasePrice,
        ),

      isActive: item.isActive,
      description: item.description,

      importedAt:
        item.importedAt.toISOString(),
      sourceSyncedAt:
        item.sourceSyncedAt.toISOString(),
    };
  }

  private buildWhere(
    filters: CatalogFilters,
  ): Prisma.ArsenCatalogItemWhereInput {
    const where:
      Prisma.ArsenCatalogItemWhereInput = {};

    const query = filters.q?.trim();

    if (query != null && query.length > 0) {
      const conditions:
        Prisma.ArsenCatalogItemWhereInput[] = [
          {
            persianName: {
              contains: query,
              mode: 'insensitive',
            },
          },
          {
            genericName: {
              contains: query,
              mode: 'insensitive',
            },
          },
          {
            persianBrandName: {
              contains: query,
              mode: 'insensitive',
            },
          },
          {
            brandName: {
              contains: query,
              mode: 'insensitive',
            },
          },
          {
            shapeName: {
              contains: query,
              mode: 'insensitive',
            },
          },
          {
            description: {
              contains: query,
              mode: 'insensitive',
            },
          },
        ];

      if (/^\d+$/.test(query)) {
        try {
          conditions.push({
            arsenDrugId: BigInt(query),
          });
        } catch {
          // Ignore an invalid numeric search value.
        }
      }

      where.OR = conditions;
    }

    const category =
      filters.category?.trim().toUpperCase();

    if (
      category != null &&
      category.length > 0
    ) {
      if (
        category !== 'DRUG' &&
        category !== 'GOODS'
      ) {
        throw new BadRequestException(
          'category must be DRUG or GOODS.',
        );
      }

      where.category = category;
    }

    const active =
      filters.active?.trim().toUpperCase();

    if (
      active != null &&
      active.length > 0 &&
      active !== 'ALL'
    ) {
      if (active === 'ACTIVE') {
        where.isActive = true;
      } else if (active === 'INACTIVE') {
        where.isActive = false;
      } else {
        throw new BadRequestException(
          'active must be ACTIVE, INACTIVE, or ALL.',
        );
      }
    }

    return where;
  }

  private readPositiveInteger(
    raw: string | undefined,
    field: string,
  ): number | null {
    const normalized = raw?.trim();

    if (
      normalized == null ||
      normalized.length === 0
    ) {
      return null;
    }

    if (!/^\d+$/.test(normalized)) {
      throw new BadRequestException(
        `${field} must be a positive integer.`,
      );
    }

    const value = Number(normalized);

    if (
      !Number.isSafeInteger(value) ||
      value < 1
    ) {
      throw new BadRequestException(
        `${field} must be a positive integer.`,
      );
    }

    return value;
  }

  private readPageSize(
    raw: string | undefined,
  ): number {
    const value =
      this.readPositiveInteger(
        raw,
        'pageSize',
      );

    if (value == null) {
      return DEFAULT_PAGE_SIZE;
    }

    if (!ALLOWED_PAGE_SIZES.has(value)) {
      throw new BadRequestException(
        'pageSize must be one of 25, 50, or 100.',
      );
    }

    return value;
  }

  private decimalString(
    value: { toString(): string } | null,
  ): string | null {
    return value == null
      ? null
      : value.toString();
  }
}