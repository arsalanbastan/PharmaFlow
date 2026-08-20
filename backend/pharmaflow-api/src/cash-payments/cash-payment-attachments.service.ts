import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';

import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { CashPaymentAttachmentStorageService } from './cash-payment-attachment-storage.service';
import { ConfirmCashPaymentAttachmentDto } from './dto/confirm-cash-payment-attachment.dto';
import { PrepareCashPaymentAttachmentDto } from './dto/prepare-cash-payment-attachment.dto';

type AttachmentChangesQuery = {
  updatedAfter?: string;
  afterId?: string;
  limit?: string;
};

const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

@Injectable()
export class CashPaymentAttachmentsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
    private readonly storage: CashPaymentAttachmentStorageService,
  ) {}

  async prepareUpload(dto: PrepareCashPaymentAttachmentDto) {
    await this.requireActiveCashPayment(dto.cashPaymentId);

    const attachmentId = dto.id?.trim() || randomUUID();

    const prepared = await this.storage.createUploadUrl({
      cashPaymentId: dto.cashPaymentId,
      attachmentId,
      mimeType: dto.mimeType,
    });

    return {
      attachmentId,
      storageKey: prepared.storageKey,
      uploadUrl: prepared.uploadUrl,
      expiresInSeconds: prepared.expiresInSeconds,
    };
  }

  async confirmUpload(dto: ConfirmCashPaymentAttachmentDto) {
    await this.requireActiveCashPayment(dto.cashPaymentId);

    const storageKey = await this.storage.verifyUploadedObject({
      cashPaymentId: dto.cashPaymentId,
      attachmentId: dto.id,
      mimeType: dto.mimeType,
      expectedFileSize: dto.fileSize,
    });

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.cashPaymentAttachment.findUnique({
        where: {
          id: dto.id,
        },
      });

      if (previous != null && previous.cashPaymentId !== dto.cashPaymentId) {
        throw new BadRequestException(
          'Attachment UUID already belongs to another cash payment.',
        );
      }

      const result = await tx.cashPaymentAttachment.upsert({
        where: {
          id: dto.id,
        },
        create: {
          id: dto.id,
          cashPaymentId: dto.cashPaymentId,
          kind: dto.kind,
          fileName: dto.fileName,
          mimeType: dto.mimeType,
          originalFileSize: dto.originalFileSize,
          fileSize: dto.fileSize,
          sha256: dto.sha256.toLowerCase(),
          storageKey,
        },
        update: {
          kind: dto.kind,
          fileName: dto.fileName,
          mimeType: dto.mimeType,
          originalFileSize: dto.originalFileSize,
          fileSize: dto.fileSize,
          sha256: dto.sha256.toLowerCase(),
          storageKey,
          deletedAt: null,
        },
      });

      await this.auditLog.record(
        {
          action: previous == null ? 'CREATE' : 'UPDATE',
          entityType: 'CASH_PAYMENT_ATTACHMENT',
          entityId: result.id,
          before: previous,
          after: result,
        },
        tx,
      );

      return result;
    });
  }

  async findAll(cashPaymentId?: string) {
    return this.prisma.cashPaymentAttachment.findMany({
      where: {
        deletedAt: null,
        ...(cashPaymentId == null || cashPaymentId.trim().length === 0
          ? {}
          : {
              cashPaymentId: cashPaymentId.trim(),
            }),
      },
      orderBy: [
        {
          createdAt: 'desc',
        },
        {
          id: 'asc',
        },
      ],
    });
  }

  async findChanges(query: AttachmentChangesQuery) {
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

    const rows = await this.prisma.cashPaymentAttachment.findMany({
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

  async createDownloadUrl(id: string) {
    const attachment = await this.prisma.cashPaymentAttachment.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });

    if (attachment == null) {
      throw new NotFoundException('Cash payment attachment not found.');
    }

    const prepared = await this.storage.createDownloadUrl(
      attachment.storageKey,
    );

    return {
      attachment,
      downloadUrl: prepared.downloadUrl,
      expiresInSeconds: prepared.expiresInSeconds,
    };
  }

  async remove(id: string) {
    const existing = await this.prisma.cashPaymentAttachment.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });

    if (existing == null) {
      throw new NotFoundException('Cash payment attachment not found.');
    }

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.cashPaymentAttachment.findUnique({
        where: {
          id,
        },
      });

      const deleted = await tx.cashPaymentAttachment.update({
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
          entityType: 'CASH_PAYMENT_ATTACHMENT',
          entityId: deleted.id,
          before: previous,
          after: deleted,
        },
        tx,
      );

      return deleted;
    });
  }

  private async requireActiveCashPayment(cashPaymentId: string) {
    const payment = await this.prisma.cashPayment.findFirst({
      where: {
        id: cashPaymentId,
        deletedAt: null,
      },
      select: {
        id: true,
      },
    });

    if (payment == null) {
      throw new NotFoundException('Cash payment not found.');
    }

    return payment;
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
