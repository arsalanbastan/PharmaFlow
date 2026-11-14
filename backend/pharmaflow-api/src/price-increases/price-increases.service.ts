import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma, type PriceIncrease } from '@prisma/client';
import { createHash, randomUUID } from 'node:crypto';
import { PrismaService } from '../database/prisma/prisma.service';
import { AuditLogService } from '../audit/audit-log.service';
import { AuthPrincipal } from '../auth/auth.types';
import { normalizeOrderSearchText } from '../orders/order-similarity';
import {
  CreatePriceIncreaseDto,
  ConfirmPriceIncreaseDto,
  UpdatePriceIncreaseDto,
  CancelPriceIncreaseDto,
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
    return (await this.createBatch([dto], actor)).items[0];
  }

  async createBatch(
    dtos: CreatePriceIncreaseDto[],
    actor: AuthPrincipal,
    requestKey?: string,
  ) {
    for (const date of new Set(dtos.map((dto) => dto.effectiveDate))) {
      validateJalaliDate(date);
    }
    const rows = dtos.map((dto) => ({ dto, ...this.prepareRow(dto) }));
    const ids = requestKey
      ? rows.map((_, index) => {
          const hash = createHash('sha256')
            .update(`${actor.userId}:${requestKey}:${index}`)
            .digest('hex');
          return `${hash.slice(0, 8)}-${hash.slice(8, 12)}-4${hash.slice(13, 16)}-8${hash.slice(17, 20)}-${hash.slice(20, 32)}`;
        })
      : null;
    return this.prisma.$transaction(async (tx) => {
      if (requestKey && ids) {
        await tx.$queryRaw`SELECT 1 AS locked FROM pg_advisory_xact_lock(hashtextextended(${actor.userId + ':' + requestKey}, 0))`;
        const existing = await tx.priceIncrease.findMany({ where: { id: { in: ids } } });
        if (existing.length) {
          if (existing.length !== rows.length || rows.some(({ dto, productName, source }, index) => {
            const item = existing.find((entry) => entry.id === ids[index]);
            return !item || item.productName !== productName || item.source !== source ||
              item.category !== dto.category || item.effectiveDate !== dto.effectiveDate ||
              !item.newPrice.equals(dto.newPrice);
          })) throw new BadRequestException('این درخواست قبلاً با اطلاعات دیگری ثبت شده است.');
          return { items: existing };
        }
      }
      const items: PriceIncrease[] = [];
      for (const [index, { dto, productName, source, productItems }] of rows.entries()) {
        const item = await tx.priceIncrease.create({
          data: {
            ...(ids && { id: ids[index] }),
            productName,
            productItems,
            normalizedProductName: normalizeOrderSearchText([productName, ...productItems].join(' ')),
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
        items.push(item);
      }
      return { items };
    });
  }

  private prepareRow(dto: CreatePriceIncreaseDto) {
    const productName = dto.productName.trim();
    const source = dto.source.trim();
    const productItems = [...new Set(dto.productItems?.map((item) => item.trim()).filter(Boolean))];
    if (
      !productName ||
      !source ||
      !/^\d{1,16}(\.\d{1,2})?$/.test(dto.newPrice) ||
      new Prisma.Decimal(dto.newPrice).lte(0)
    )
      throw new BadRequestException(
        'Product, source and positive price are required.',
      );
    return { productName, source, productItems };
  }

  async update(id: string, dto: UpdatePriceIncreaseDto, actor: AuthPrincipal) {
    const productName = dto.productName.trim();
    const source = dto.source.trim();
    const productItems = [...new Set(dto.productItems?.map((item) => item.trim()).filter(Boolean))];
    if (
      !productName || !source ||
      !/^\d{1,16}(\.\d{1,2})?$/.test(dto.newPrice) ||
      new Prisma.Decimal(dto.newPrice).lte(0)
    ) throw new BadRequestException('Product, source and positive price are required.');
    validateJalaliDate(dto.effectiveDate);
    return this.prisma.$transaction(async (tx) => {
      await this.lockNotice(tx, id);
      const current = await tx.priceIncrease.findUnique({
        where: { id },
        include: { confirmations: { take: 1 } },
      });
      if (!current) throw new NotFoundException('Price increase not found.');
      if (current.canceledAt) throw new BadRequestException('Canceled price increases cannot be edited.');
      if (current.confirmations.length) throw new BadRequestException('A confirmed price increase cannot be edited; cancel it and create a corrected entry.');
      const updated = await tx.priceIncrease.update({
        where: { id },
        data: {
          productName,
          productItems,
          normalizedProductName: normalizeOrderSearchText([productName, ...productItems].join(' ')),
          category: dto.category,
          newPrice: dto.newPrice,
          effectiveDate: dto.effectiveDate,
          source,
          notes: dto.notes?.trim(),
        },
      });
      await this.audit.record({
        action: 'PRICE_INCREASE_UPDATED',
        entityType: 'PriceIncrease',
        entityId: id,
        before: current,
        after: updated,
      }, tx);
      return updated;
    });
  }

  async cancel(id: string, dto: CancelPriceIncreaseDto, actor: AuthPrincipal) {
    const reason = dto.reason.trim();
    if (!reason) throw new BadRequestException('Cancellation reason is required.');
    return this.prisma.$transaction(async (tx) => {
      await this.lockNotice(tx, id);
      const current = await tx.priceIncrease.findUnique({ where: { id } });
      if (!current) throw new NotFoundException('Price increase not found.');
      if (current.canceledAt) return current;
      const canceled = await tx.priceIncrease.update({
        where: { id },
        data: {
          canceledAt: new Date(),
          canceledByUserId: actor.userId,
          canceledByName: actor.displayName,
          cancellationReason: reason,
        },
      });
      await this.audit.record({
        action: 'PRICE_INCREASE_CANCELED',
        entityType: 'PriceIncrease',
        entityId: id,
        before: current,
        after: canceled,
      }, tx);
      return canceled;
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
    if (query.status && !['PENDING', 'CONFIRMED', 'CANCELED'].includes(query.status))
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
      ...(query.status === 'CANCELED' ? { canceledAt: { not: null } } : { canceledAt: null }),
      ...(query.from || query.to
        ? { effectiveDate: { gte: query.from || undefined, lte: query.to || undefined } }
        : {}),
    };
    // The item count is row-specific. Compute completed notice IDs in SQL so
    // filtering and pagination apply to the same set.
    if (query.status === 'PENDING' || query.status === 'CONFIRMED') {
      const completed = await this.prisma.$queryRaw<{ id: string }[]>`
        SELECT p.id
        FROM price_increases p
        JOIN price_increase_confirmations c ON c."priceIncreaseId" = p.id
        WHERE p."canceledAt" IS NULL
        ${actor.role === 'STAFF' ? Prisma.sql`AND c."userId" = ${actor.userId}::uuid` : Prisma.empty}
        GROUP BY p.id
        HAVING COUNT(DISTINCT c."itemIndex") = GREATEST(cardinality(p."productItems"), 1)
      `;
      const ids = completed.map((record) => record.id);
      where.id = query.status === 'CONFIRMED' ? { in: ids } : { notIn: ids };
    }
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

  async confirm(id: string, actor: AuthPrincipal, dto: ConfirmPriceIncreaseDto = {}) {
    return this.prisma.$transaction(async (tx) => {
      await this.lockNotice(tx, id);
      const item = await tx.priceIncrease.findUnique({ where: { id } });
      if (!item) throw new NotFoundException('Price increase not found.');
      if (item.canceledAt) throw new BadRequestException('Canceled price increases cannot be confirmed.');
      const itemIndex = dto.itemIndex ?? -1;
      const itemCount = item.productItems?.length ?? 0;
      if (itemCount === 0 ? itemIndex !== -1 : itemIndex < 0 || itemIndex >= itemCount) {
        throw new BadRequestException('Select a valid item to confirm.');
      }
      // Unique key and skipDuplicates make concurrent retries idempotent, preserving the first server timestamp.
      const result = await tx.priceIncreaseConfirmation.createMany({
        data: [
          {
            priceIncreaseId: id,
            userId: actor.userId,
            displayName: actor.displayName,
            itemIndex,
            note: dto.note?.trim() || null,
          },
        ],
        skipDuplicates: true,
      });
      const confirmation = await tx.priceIncreaseConfirmation.findUniqueOrThrow(
        {
          where: {
            priceIncreaseId_userId_itemIndex: {
              priceIncreaseId: id,
              userId: actor.userId,
              itemIndex,
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

  private async lockNotice(tx: Prisma.TransactionClient, id: string) {
    await tx.$queryRaw`SELECT id FROM price_increases WHERE id = ${id}::uuid FOR UPDATE`;
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
