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

type DecimalLike = {
  toString(): string;
};

type SearchableCatalogRow = {
  id: string;
  ingestSequence: bigint;
  arsenDrugId: bigint;
  category: string;
  persianName: string | null;
  genericName: string | null;
  persianBrandName: string | null;
  brandName: string | null;
  unit: string | null;
  shapeName: string | null;
  packetQuantity: number | null;
  salesPrice: DecimalLike | null;
  lastPurchasePrice: DecimalLike | null;
  isActive: boolean;
  sourceSyncedAt: Date;
};

type SearchQuery = {
  normalized: string;
  tokens: string[];
};

const DEFAULT_PAGE_SIZE = 50;
const ALLOWED_PAGE_SIZES = new Set([25, 50, 100]);

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class CatalogService {
  constructor(private readonly prisma: PrismaService) {}

  async findAll(filters: CatalogFilters = {}) {
    const baseWhere = this.buildBaseWhere(filters);

    const requestedPage =
      this.readPositiveInteger(filters.page, 'page') ?? 1;

    const pageSize = this.readPageSize(filters.pageSize);
    const search = this.parseSearchQuery(filters.q);

    if (search == null) {
      return this.findWithoutSearch(
        baseWhere,
        requestedPage,
        pageSize,
      );
    }

    return this.findWithSmartSearch(
      baseWhere,
      search,
      requestedPage,
      pageSize,
    );
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

  private async findWithoutSearch(
    where: Prisma.ArsenCatalogItemWhereInput,
    requestedPage: number,
    pageSize: number,
  ) {
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
          ingestSequence: true,
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
      items: rows.map((row) =>
        this.serializeSummary(row),
      ),
      page,
      pageSize,
      totalCount,
      totalPages,
    };
  }

  private async findWithSmartSearch(
    baseWhere: Prisma.ArsenCatalogItemWhereInput,
    search: SearchQuery,
    requestedPage: number,
    pageSize: number,
  ) {
    const where: Prisma.ArsenCatalogItemWhereInput = {
      ...baseWhere,
      AND: search.tokens.map((token) =>
        this.buildTokenCondition(token),
      ),
    };

    const rows =
      await this.prisma.arsenCatalogItem.findMany({
        where,
        select: {
          id: true,
          ingestSequence: true,
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
      });

    const ranked = rows
      .filter((row) =>
        this.matchesAllTokens(row, search.tokens),
      )
      .map((row) => ({
        row,
        score: this.scoreRow(row, search),
      }))
      .sort((a, b) => {
        if (a.score !== b.score) {
          return b.score - a.score;
        }

        if (
          a.row.ingestSequence ===
          b.row.ingestSequence
        ) {
          return 0;
        }

        return a.row.ingestSequence >
          b.row.ingestSequence
          ? -1
          : 1;
      });

    const totalCount = ranked.length;

    const totalPages =
      Math.max(1, Math.ceil(totalCount / pageSize));

    const page =
      Math.min(requestedPage, totalPages);

    const start =
      (page - 1) * pageSize;

    const pageRows =
      ranked.slice(start, start + pageSize);

    return {
      items: pageRows.map(({ row }) =>
        this.serializeSummary(row),
      ),
      page,
      pageSize,
      totalCount,
      totalPages,
    };
  }

  private serializeSummary(
    row: SearchableCatalogRow,
  ) {
    return {
      id: row.id,
      arsenDrugId:
        row.arsenDrugId.toString(),
      category: row.category,
      persianName: row.persianName,
      genericName: row.genericName,
      persianBrandName:
        row.persianBrandName,
      brandName: row.brandName,
      unit: row.unit,
      shapeName: row.shapeName,
      packetQuantity: row.packetQuantity,
      salesPrice:
        this.decimalString(row.salesPrice),
      lastPurchasePrice:
        this.decimalString(
          row.lastPurchasePrice,
        ),
      isActive: row.isActive,
      sourceSyncedAt:
        row.sourceSyncedAt.toISOString(),
    };
  }

  private buildBaseWhere(
    filters: CatalogFilters,
  ): Prisma.ArsenCatalogItemWhereInput {
    const where:
      Prisma.ArsenCatalogItemWhereInput = {};

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

  private parseSearchQuery(
    raw: string | undefined,
  ): SearchQuery | null {
    const normalized =
      this.normalizeSearchText(raw ?? '');

    if (normalized.length === 0) {
      return null;
    }

    const tokens = [
      ...new Set(
        normalized
          .split(' ')
          .map((token) => token.trim())
          .filter((token) => token.length > 0),
      ),
    ];

    if (tokens.length === 0) {
      return null;
    }

    return {
      normalized,
      tokens,
    };
  }

  private buildTokenCondition(
    token: string,
  ): Prisma.ArsenCatalogItemWhereInput {
    const conditions:
      Prisma.ArsenCatalogItemWhereInput[] = [];

    for (const variant of this.searchVariants(token)) {
      conditions.push(
        {
          persianName: {
            contains: variant,
            mode: 'insensitive',
          },
        },
        {
          genericName: {
            contains: variant,
            mode: 'insensitive',
          },
        },
        {
          persianBrandName: {
            contains: variant,
            mode: 'insensitive',
          },
        },
        {
          brandName: {
            contains: variant,
            mode: 'insensitive',
          },
        },
      );
    }

    if (/^\d+$/.test(token)) {
      try {
        conditions.push({
          arsenDrugId: BigInt(token),
        });
      } catch {
        // Numeric text outside BigInt range is ignored.
      }
    }

    return {
      OR: conditions,
    };
  }

  private searchVariants(
    token: string,
  ): string[] {
    const variants = new Set<string>([token]);

    const replacements = [
      ['ی', 'ي'],
      ['ی', 'ى'],
      ['ک', 'ك'],
    ] as const;

    for (const [from, to] of replacements) {
      for (const value of [...variants]) {
        variants.add(
          value.split(from).join(to),
        );
      }
    }

    return [...variants];
  }

  private matchesAllTokens(
    row: SearchableCatalogRow,
    tokens: string[],
  ): boolean {
    const fields =
      this.normalizedSearchFields(row);

    return tokens.every((token) =>
      fields.some((field) =>
        field.text.includes(token),
      ),
    );
  }

  private scoreRow(
    row: SearchableCatalogRow,
    search: SearchQuery,
  ): number {
    const fields =
      this.normalizedSearchFields(row);

    let score = 0;

    const arsenId =
      row.arsenDrugId.toString();

    if (arsenId === search.normalized) {
      score += 12000;
    }

    for (const field of fields) {
      const text = field.text;

      if (text.length === 0) {
        continue;
      }

      if (text === search.normalized) {
        score += 9000 + field.weight;
      } else if (
        text.startsWith(search.normalized)
      ) {
        score += 6500 + field.weight;
      } else if (
        text.includes(search.normalized)
      ) {
        score += 5200 + field.weight;
      }

      const positions =
        search.tokens.map((token) =>
          text.indexOf(token),
        );

      if (
        positions.every(
          (position) => position >= 0,
        )
      ) {
        score += 2600 + field.weight;

        const starts =
          positions.filter(
            (position) => position >= 0,
          );

        const ends =
          search.tokens.map(
            (token, index) =>
              positions[index] + token.length,
          );

        const span =
          Math.max(...ends) -
          Math.min(...starts);

        score += Math.max(
          0,
          900 - span * 8,
        );
      }

      for (const token of search.tokens) {
        if (text === token) {
          score += 900 + field.weight;
        } else if (
          text.startsWith(token)
        ) {
          score += 650 + field.weight;
        } else if (
          text.includes(token)
        ) {
          score += 400 + field.weight;
        }
      }

      score -= Math.min(
        250,
        Math.abs(
          text.length -
            search.normalized.length,
        ),
      );
    }

    return score;
  }

  private normalizedSearchFields(
    row: SearchableCatalogRow,
  ): Array<{
    text: string;
    weight: number;
  }> {
    return [
      {
        text: this.normalizeSearchText(
          row.genericName ?? '',
        ),
        weight: 100,
      },
      {
        text: this.normalizeSearchText(
          row.persianName ?? '',
        ),
        weight: 95,
      },
      {
        text: this.normalizeSearchText(
          row.persianBrandName ?? '',
        ),
        weight: 85,
      },
      {
        text: this.normalizeSearchText(
          row.brandName ?? '',
        ),
        weight: 80,
      },
      {
        text: row.arsenDrugId.toString(),
        weight: 40,
      },
    ];
  }

  private normalizeSearchText(
    value: string,
  ): string {
    return value
      .normalize('NFKC')
      .replace(/[يى]/g, 'ی')
      .replace(/ك/g, 'ک')
      .replace(/[ۀة]/g, 'ه')
      .replace(/[ؤ]/g, 'و')
      .replace(/[أإ]/g, 'ا')
      .replace(/[\u200c\u200d\u2060]/g, ' ')
      .replace(/\u0640/g, '')
      .replace(/[\u064b-\u065f\u0670]/g, '')
      .replace(
        /[۰-۹]/g,
        (char) =>
          String(
            char.charCodeAt(0) - 0x06f0,
          ),
      )
      .replace(
        /[٠-٩]/g,
        (char) =>
          String(
            char.charCodeAt(0) - 0x0660,
          ),
      )
      .toLowerCase()
      .replace(
        /[^0-9a-z\u0600-\u06ff]+/g,
        ' ',
      )
      .replace(/\s+/g, ' ')
      .trim();
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
    value: DecimalLike | null,
  ): string | null {
    return value == null
      ? null
      : value.toString();
  }
}