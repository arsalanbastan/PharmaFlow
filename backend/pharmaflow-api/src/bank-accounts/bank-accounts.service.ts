import { BadRequestException, Injectable } from '@nestjs/common';

import { PrismaService } from '../database/prisma/prisma.service';
import { AuditLogService } from '../audit/audit-log.service';
import { CreateBankAccountDto } from './dto/create-bank-account.dto';
import { UpdateBankAccountDto } from './dto/update-bank-account.dto';

type BankAccountChangesQuery = {
  updatedAfter?: string;
  afterId?: string;
  limit?: string;
};

const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class BankAccountsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async create(createBankAccountDto: CreateBankAccountDto) {
    const requestedId = createBankAccountDto.id?.trim() || undefined;

    const data = {
      bankName: createBankAccountDto.bankName,
      accountTitle: createBankAccountDto.accountTitle,
      accountHolder: createBankAccountDto.accountHolder,
      accountNumber: createBankAccountDto.accountNumber,
      cardNumber: createBankAccountDto.cardNumber,
      shebaNumber: createBankAccountDto.shebaNumber,
      notes: createBankAccountDto.notes,
      archivedAt: createBankAccountDto.archivedAt,
    };

    if (requestedId == null) {
      return this.prisma.$transaction(async (tx) => {
        const created = await tx.bankAccount.create({
          data,
        });

        await this.auditLog.record(
          {
            action: 'CREATE',
            entityType: 'BANK_ACCOUNT',
            entityId: created.id,
            after: created,
          },
          tx,
        );

        return created;
      });
    }

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.bankAccount.findUnique({
        where: {
          id: requestedId,
        },
      });

      const result = await tx.bankAccount.upsert({
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
          entityType: 'BANK_ACCOUNT',
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
    return this.prisma.bankAccount.findMany({
      where: {
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async findChanges(query: BankAccountChangesQuery) {
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

    const rows = await this.prisma.bankAccount.findMany({
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
    return this.prisma.bankAccount.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
  }

  async update(id: string, updateBankAccountDto: UpdateBankAccountDto) {
    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.bankAccount.findUnique({
        where: {
          id,
        },
      });

      const updated = await tx.bankAccount.update({
        where: {
          id,
        },
        data: updateBankAccountDto,
      });

      await this.auditLog.record(
        {
          action: 'UPDATE',
          entityType: 'BANK_ACCOUNT',
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
      const previous = await tx.bankAccount.findUnique({
        where: {
          id,
        },
      });

      const deleted = await tx.bankAccount.update({
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
          entityType: 'BANK_ACCOUNT',
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
