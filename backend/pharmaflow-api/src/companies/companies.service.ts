import { BadRequestException, Injectable } from '@nestjs/common';

import { PrismaService } from '../database/prisma/prisma.service';
import { AuditLogService } from '../audit/audit-log.service';
import { CreateCompanyDto } from './dto/create-company.dto';
import { UpdateCompanyDto } from './dto/update-company.dto';

type CompanyChangesQuery = {
  updatedAfter?: string;
  afterId?: string;
  limit?: string;
};

const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class CompaniesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async create(createCompanyDto: CreateCompanyDto) {
    const requestedId = createCompanyDto.id?.trim() || undefined;

    const data = {
      name: createCompanyDto.name,
      nationalId: createCompanyDto.nationalId,
      economicCode: createCompanyDto.economicCode,
      bankName: createCompanyDto.bankName,
      accountNumber: createCompanyDto.accountNumber,
      cardNumber: createCompanyDto.cardNumber,
      shebaNumber: createCompanyDto.shebaNumber,
      notes: createCompanyDto.notes,
      visitorName: createCompanyDto.visitorName,
      visitorPhone: createCompanyDto.visitorPhone,
      accountantName: createCompanyDto.accountantName,
      accountantPhone: createCompanyDto.accountantPhone,
      archivedAt: createCompanyDto.archivedAt,
    };

    /*
     * Backward-compatible caller:
     * Prisma generates the UUID when the client did not provide one.
     */
    if (requestedId == null) {
      return this.prisma.$transaction(async (tx) => {
        const created = await tx.company.create({
          data,
        });

        await this.auditLog.record(
          {
            action: 'CREATE',
            entityType: 'COMPANY',
            entityId: created.id,
            after: created,
          },
          tx,
        );

        return created;
      });
    }

    /*
     * Offline-first clients provide the UUID before the first request.
     *
     * Preserve the existing idempotent upsert behavior:
     * - missing server row  => CREATE
     * - existing server row => UPDATE to the latest local snapshot
     */
    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.company.findUnique({
        where: {
          id: requestedId,
        },
      });

      const result = await tx.company.upsert({
        where: {
          id: requestedId,
        },
        create: {
          id: requestedId,
          ...data,
        },
        update: data,
      });

      await this.auditLog.record(
        {
          action: previous == null ? 'CREATE' : 'UPDATE',
          entityType: 'COMPANY',
          entityId: result.id,
          before: previous,
          after: result,
        },
        tx,
      );

      return result;
    });
  }

  async findAll() {
    return this.prisma.company.findMany({
      where: {
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async findChanges(query: CompanyChangesQuery) {
    const updatedAfterText = query.updatedAfter?.trim() || undefined;

    const afterId = query.afterId?.trim() || undefined;

    if ((updatedAfterText == null) !== (afterId == null)) {
      throw new BadRequestException(
        'updatedAfter and afterId must be provided together.',
      );
    }

    let updatedAfter: Date | undefined;

    if (updatedAfterText != null) {
      updatedAfter = new Date(updatedAfterText);

      if (Number.isNaN(updatedAfter.getTime())) {
        throw new BadRequestException(
          'updatedAfter must be a valid ISO-8601 date.',
        );
      }

      if (afterId == null || !UUID_PATTERN.test(afterId)) {
        throw new BadRequestException('afterId must be a valid UUID.');
      }
    }

    const limit = this.parseChangesLimit(query.limit);

    const where =
      updatedAfter != null && afterId != null
        ? {
            OR: [
              {
                updatedAt: {
                  gt: updatedAfter,
                },
              },
              {
                updatedAt: updatedAfter,
                id: {
                  gt: afterId,
                },
              },
            ],
          }
        : undefined;

    const rows = await this.prisma.company.findMany({
      where,
      orderBy: [
        {
          updatedAt: 'asc',
        },
        {
          id: 'asc',
        },
      ],
      take: limit + 1,
    });

    const hasMore = rows.length > limit;

    const items = hasMore ? rows.slice(0, limit) : rows;

    const lastItem = items.length > 0 ? items[items.length - 1] : null;

    const nextCursor =
      lastItem != null
        ? {
            updatedAt: lastItem.updatedAt.toISOString(),
            id: lastItem.id,
          }
        : updatedAfter != null && afterId != null
          ? {
              updatedAt: updatedAfter.toISOString(),
              id: afterId,
            }
          : null;

    return {
      items,
      hasMore,
      nextCursor,
    };
  }

  async findOne(id: string) {
    return this.prisma.company.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
  }

  async update(id: string, updateCompanyDto: UpdateCompanyDto) {
    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.company.findUnique({
        where: {
          id,
        },
      });

      const updated = await tx.company.update({
        where: {
          id,
        },
        data: updateCompanyDto,
      });

      await this.auditLog.record(
        {
          action: 'UPDATE',
          entityType: 'COMPANY',
          entityId: updated.id,
          before: previous,
          after: updated,
        },
        tx,
      );

      return updated;
    });
  }

  async remove(id: string) {
    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.company.findUnique({
        where: {
          id,
        },
      });

      const deleted = await tx.company.update({
        where: {
          id,
        },
        data: {
          deletedAt: new Date(),
        },
      });

      await this.auditLog.record(
        {
          action: 'DELETE',
          entityType: 'COMPANY',
          entityId: deleted.id,
          before: previous,
          after: deleted,
        },
        tx,
      );

      return deleted;
    });
  }

  private parseChangesLimit(rawLimit?: string) {
    if (rawLimit == null || rawLimit.trim().length === 0) {
      return DEFAULT_CHANGES_LIMIT;
    }

    const parsed = Number(rawLimit);

    if (!Number.isInteger(parsed) || parsed <= 0) {
      throw new BadRequestException('limit must be a positive integer.');
    }

    return Math.min(parsed, MAX_CHANGES_LIMIT);
  }
}
