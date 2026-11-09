import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../database/prisma/prisma.service';
import { AuditLogService } from '../audit/audit-log.service';
import { AuthPrincipal } from '../auth/auth.types';
import { normalizeOrderSearchText } from '../orders/order-similarity';
import {
  CreatePriceIncreaseDto,
  PreparePriceAttachmentDto,
} from './price-increases.dto';
import { PriceIncreaseStorageService } from './price-increase-storage.service';

export function validateJalaliDate(value: string): string {
  if (!/^1[3-6]\d{2}\/\d{2}\/\d{2}$/.test(value))
    throw new BadRequestException('Invalid Jalali date (YYYY/MM/DD).');
  const [year, month, day] = value.split('/').map(Number);
  const format = new Intl.DateTimeFormat('en-US-u-ca-persian', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    timeZone: 'UTC',
  });
  // Calendar round trip also rejects invalid Esfand 30 in non-leap years.
  const start = Date.UTC(year + 621, 0, 1);
  for (let i = 0; i < 460; i++) {
    const parts = format.formatToParts(new Date(start + i * 86400000));
    const part = (type: string) =>
      Number(parts.find((p) => p.type === type)?.value);
    if (part('year') === year && part('month') === month && part('day') === day)
      return value;
  }
  throw new BadRequestException('Invalid Jalali date.');
}

@Injectable()
export class PriceIncreasesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditLogService,
    private readonly storage: PriceIncreaseStorageService,
  ) {}

  async create(dto: CreatePriceIncreaseDto, actor: AuthPrincipal) {
    const productName = dto.productName.trim();
    const source = dto.source.trim();
    if (
      !productName ||
      !source ||
      !/^\d{1,16}(\.\d{1,2})?$/.test(dto.newPrice) ||
      new Prisma.Decimal(dto.newPrice).lte(0)
    )
      throw new BadRequestException(
        'Product, source and positive price are required.',
      );
    validateJalaliDate(dto.effectiveDate);
    return this.prisma.$transaction(async (tx) => {
      const item = await tx.priceIncrease.create({
        data: {
          productName,
          normalizedProductName: normalizeOrderSearchText(productName),
          category: dto.category,
          newPrice: dto.newPrice,
          effectiveDate: dto.effectiveDate,
          source,
          notes: dto.notes?.trim(),
          createdByUserId: actor.userId,
          createdByName: actor.displayName,
        },
      });
      await this.audit.record(
        {
          action: 'PRICE_INCREASE_CREATED',
          entityType: 'PriceIncrease',
          entityId: item.id,
          after: item,
        },
        tx,
      );
      return item;
    });
  }

  async list(
    query: {
      q?: string;
      status?: string;
      category?: string;
      from?: string;
      to?: string;
      page?: string;
    },
    actor: AuthPrincipal,
  ) {
    if (query.status && !['PENDING', 'CONFIRMED'].includes(query.status))
      throw new BadRequestException('Invalid status.');
    if (query.category && !['DRUG', 'GOODS'].includes(query.category))
      throw new BadRequestException('Invalid category.');
    if (query.from) validateJalaliDate(query.from);
    if (query.to) validateJalaliDate(query.to);
    if (query.from && query.to && query.from > query.to)
      throw new BadRequestException('Invalid date range.');
    const page = Number(query.page ?? 1);
    if (!Number.isSafeInteger(page) || page < 1 || page > 100000)
      throw new BadRequestException('Invalid page.');
    // Staff status is per employee. Manager status reflects whether anyone has confirmed.
    const scope = actor.role === 'STAFF' ? { userId: actor.userId } : {};
    const where: Prisma.PriceIncreaseWhereInput = {
      ...(query.q?.trim()
        ? {
            OR: [
              {
                normalizedProductName: {
                  contains: normalizeOrderSearchText(query.q),
                },
              },
              { source: { contains: query.q.trim(), mode: 'insensitive' } },
              { notes: { contains: query.q.trim(), mode: 'insensitive' } },
              {
                confirmations: {
                  some: {
                    displayName: {
                      contains: query.q.trim(),
                      mode: 'insensitive',
                    },
                  },
                },
              },
            ],
          }
        : {}),
      ...(query.category ? { category: query.category } : {}),
      ...(query.from || query.to
        ? { effectiveDate: { gte: query.from, lte: query.to } }
        : {}),
      ...(query.status === 'PENDING'
        ? { confirmations: { none: scope } }
        : query.status === 'CONFIRMED'
          ? { confirmations: { some: scope } }
          : {}),
    };
    const [items, total] = await this.prisma.$transaction([
      this.prisma.priceIncrease.findMany({
        where,
        include: {
          confirmations: { orderBy: { confirmedAt: 'asc' } },
          attachments: {
            where: { confirmedAt: { not: null } },
            select: {
              id: true,
              fileName: true,
              mimeType: true,
              fileSize: true,
            },
          },
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        skip: (page - 1) * 25,
        take: 25,
      }),
      this.prisma.priceIncrease.count({ where }),
    ]);
    return { items, total, page, pageSize: 25, currentUserId: actor.userId };
  }

  async confirm(id: string, actor: AuthPrincipal) {
    return this.prisma.$transaction(async (tx) => {
      if (!(await tx.priceIncrease.findUnique({ where: { id } })))
        throw new NotFoundException('Price increase not found.');
      // Unique key and skipDuplicates make concurrent retries idempotent, preserving the first server timestamp.
      const result = await tx.priceIncreaseConfirmation.createMany({
        data: [
          {
            priceIncreaseId: id,
            userId: actor.userId,
            displayName: actor.displayName,
          },
        ],
        skipDuplicates: true,
      });
      const confirmation = await tx.priceIncreaseConfirmation.findUniqueOrThrow(
        {
          where: {
            priceIncreaseId_userId: {
              priceIncreaseId: id,
              userId: actor.userId,
            },
          },
        },
      );
      if (result.count)
        await this.audit.record(
          {
            action: 'PRICE_INCREASE_CONFIRMED',
            entityType: 'PriceIncrease',
            entityId: id,
            after: confirmation,
          },
          tx,
        );
      return confirmation;
    });
  }

  async prepare(id: string, dto: PreparePriceAttachmentDto) {
    if (!(await this.prisma.priceIncrease.findUnique({ where: { id } })))
      throw new NotFoundException('Price increase not found.');
    const attachmentId = randomUUID();
    const upload = await this.storage.createUploadUrl({
      priceIncreaseId: id,
      attachmentId,
      mimeType: dto.mimeType,
    });
    await this.prisma.$transaction(async (tx) => {
      const item = await tx.priceIncreaseAttachment.create({
        data: {
          id: attachmentId,
          priceIncreaseId: id,
          ...dto,
          storageKey: upload.storageKey,
        },
      });
      await this.audit.record(
        {
          action: 'PRICE_INCREASE_ATTACHMENT_PREPARED',
          entityType: 'PriceIncrease',
          entityId: id,
          after: item,
        },
        tx,
      );
    });
    return { id: attachmentId, ...upload };
  }

  async confirmAttachment(id: string, attachmentId: string) {
    const item = await this.prisma.priceIncreaseAttachment.findFirst({
      where: { id: attachmentId, priceIncreaseId: id },
    });
    if (!item) throw new NotFoundException('Attachment not found.');
    if (item.confirmedAt) return { id: item.id };
    await this.storage.verifyUploadedObject({
      priceIncreaseId: id,
      attachmentId,
      mimeType: item.mimeType,
      expectedFileSize: item.fileSize,
    });
    await this.prisma.$transaction(async (tx) => {
      const result = await tx.priceIncreaseAttachment.updateMany({
        where: { id: attachmentId, confirmedAt: null },
        data: { confirmedAt: new Date() },
      });
      if (result.count)
        await this.audit.record(
          {
            action: 'PRICE_INCREASE_ATTACHMENT_CONFIRMED',
            entityType: 'PriceIncrease',
            entityId: id,
            after: { attachmentId },
          },
          tx,
        );
    });
    return { id: item.id };
  }

  async download(id: string, attachmentId: string) {
    const item = await this.prisma.priceIncreaseAttachment.findFirst({
      where: {
        id: attachmentId,
        priceIncreaseId: id,
        confirmedAt: { not: null },
      },
    });
    if (!item) throw new NotFoundException('Attachment not found.');
    return this.storage.createDownloadUrl(item.storageKey);
  }
}
