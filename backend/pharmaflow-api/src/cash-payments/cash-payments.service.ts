import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { enqueueCashPaymentCreatedPush } from '../push/push-outbox.service';
import { CreateCashPaymentDto } from './dto/create-cash-payment.dto';
import { UpdateCashPaymentDto } from './dto/update-cash-payment.dto';

type CashPaymentChangesQuery = {
  updatedAfter?: string;
  afterId?: string;
  limit?: string;
};

const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class CashPaymentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
  ) {}

  async create(createCashPaymentDto: CreateCashPaymentDto) {
    const requestedId = createCashPaymentDto.id?.trim() || undefined;

    const data = {
      amount: createCashPaymentDto.amount,
      paymentDate: new Date(createCashPaymentDto.paymentDate),
      companyId: createCashPaymentDto.companyId,
      bankAccountId: createCashPaymentDto.bankAccountId,
      paymentMethod: createCashPaymentDto.paymentMethod,
      trackingNumber: createCashPaymentDto.trackingNumber,
      description: createCashPaymentDto.description,
      notes: createCashPaymentDto.notes,
      archivedAt:
        createCashPaymentDto.archivedAt == null
          ? createCashPaymentDto.archivedAt
          : new Date(createCashPaymentDto.archivedAt),
    };

    if (requestedId == null) {
      return this.prisma.$transaction(async (tx) => {
        const created = await tx.cashPayment.create({
          data,
        });

        await this.auditLog.record(
          {
            action: 'CREATE',
            entityType: 'CASH_PAYMENT',
            entityId: created.id,
            after: created,
          },
          tx,
        );

        await enqueueCashPaymentCreatedPush(created.id, tx);

        return created;
      });
    }

    /*
     * Offline-first clients own the UUID before their first push.
     * CREATE is therefore idempotent by UUID, matching the current
     * Company / BankAccount / Cheque synchronization architecture.
     */
    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.cashPayment.findUnique({
        where: {
          id: requestedId,
        },
      });

      const result = await tx.cashPayment.upsert({
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
          entityType: 'CASH_PAYMENT',
          entityId: result.id,
          before: previous,
          after: result,
        },
        tx,
      );

      if (previous == null) {
        await enqueueCashPaymentCreatedPush(result.id, tx);
      }

      return result;
    });
  }

  async findAll() {
    return this.prisma.cashPayment.findMany({
      where: {
        deletedAt: null,
      },
      orderBy: [
        {
          paymentDate: 'desc',
        },
        {
          createdAt: 'desc',
        },
      ],
    });
  }

  async findChanges(query: CashPaymentChangesQuery) {
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

    const rows = await this.prisma.cashPayment.findMany({
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
    return this.prisma.cashPayment.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
  }

  async update(id: string, updateCashPaymentDto: UpdateCashPaymentDto) {
    const existing = await this.prisma.cashPayment.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });

    if (existing == null) {
      throw new NotFoundException('Cash payment not found.');
    }

    const data: Prisma.CashPaymentUncheckedUpdateInput = {};

    if (updateCashPaymentDto.amount !== undefined) {
      data.amount = updateCashPaymentDto.amount;
    }

    if (updateCashPaymentDto.paymentDate !== undefined) {
      data.paymentDate = new Date(updateCashPaymentDto.paymentDate);
    }

    if (updateCashPaymentDto.companyId !== undefined) {
      data.companyId = updateCashPaymentDto.companyId;
    }

    if (updateCashPaymentDto.bankAccountId !== undefined) {
      data.bankAccountId = updateCashPaymentDto.bankAccountId;
    }

    if (updateCashPaymentDto.paymentMethod !== undefined) {
      data.paymentMethod = updateCashPaymentDto.paymentMethod;
    }

    if (updateCashPaymentDto.trackingNumber !== undefined) {
      data.trackingNumber = updateCashPaymentDto.trackingNumber;
    }

    if (updateCashPaymentDto.description !== undefined) {
      data.description = updateCashPaymentDto.description;
    }

    if (updateCashPaymentDto.notes !== undefined) {
      data.notes = updateCashPaymentDto.notes;
    }

    if (updateCashPaymentDto.archivedAt !== undefined) {
      data.archivedAt =
        updateCashPaymentDto.archivedAt == null
          ? null
          : new Date(updateCashPaymentDto.archivedAt);
    }

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.cashPayment.findUnique({
        where: {
          id,
        },
      });

      const updated = await tx.cashPayment.update({
        where: {
          id,
        },
        data,
      });

      await this.auditLog.record(
        {
          action: 'UPDATE',
          entityType: 'CASH_PAYMENT',
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
    const existing = await this.prisma.cashPayment.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });

    if (existing == null) {
      throw new NotFoundException('Cash payment not found.');
    }

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.cashPayment.findUnique({
        where: {
          id,
        },
      });

      const deleted = await tx.cashPayment.update({
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
          entityType: 'CASH_PAYMENT',
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
