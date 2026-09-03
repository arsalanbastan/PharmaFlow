import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { createHash } from 'node:crypto';

import { AuditContextService } from '../audit/audit-context.service';
import { AuditLogService } from '../audit/audit-log.service';
import type { AppUserRole } from '../auth/auth.types';
import { PrismaService } from '../database/prisma/prisma.service';
import { PushOutboxService } from '../push/push-outbox.service';
import { AssignOrderRequestDto } from './dto/assign-order-request.dto';
import { CheckOrderDuplicateDto } from './dto/check-order-duplicate.dto';
import { ConfirmOrderPhotoDto } from './dto/confirm-order-photo.dto';
import { CreateOrderRequestDto } from './dto/create-order-request.dto';
import { PrepareOrderPhotoDto } from './dto/prepare-order-photo.dto';
import { UpdateOrderCategoryDto } from './dto/update-order-category.dto';
import { UpdatePendingOrderRequestDto } from './dto/update-pending-order-request.dto';
import { UploadWebOrderPhotoDto } from './dto/upload-web-order-photo.dto';
import {
  isOrderTextSimilar,
  normalizeOrderSearchText,
  scoreOrderTextSimilarity,
} from './order-similarity';
import { OrderPhotoStorageService } from './order-photo-storage.service';

type OrderChangesQuery = {
  updatedAfter?: string;
  afterId?: string;
  limit?: string;
};

type OrderListQuery = {
  status?: string;
  category?: string;
};

type AuthenticatedOrderActor = {
  userId: string;
  displayName: string;
  role: AppUserRole;
};

const DEFAULT_CHANGES_LIMIT = 200;
const MAX_CHANGES_LIMIT = 500;

const VALID_CATEGORIES = new Set(['DRUG', 'GOODS']);

const VALID_STATUSES = new Set([
  'PENDING',
  'ORDERED',
  'RECEIVED',
  'CANCELED',
  'DELETED',
]);

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const PHOTO_CLEANUP_STATUSES = ['ORDERED', 'RECEIVED', 'CANCELED', 'DELETED'];
const PHOTO_CLEANUP_BATCH_SIZE = 50;
const PHOTO_CLEANUP_RETRY_MS = 5 * 60 * 1000;
const CANCELED_ORDER_RETENTION_MS = 3 * 24 * 60 * 60 * 1000;
const CANCELED_ORDER_EXPIRY_BATCH_SIZE = 100;
const ACTIVE_DUPLICATE_STATUSES = new Set(['PENDING', 'ORDERED']);
const ACTIVE_STAFF_DASHBOARD_STATUSES = ['PENDING', 'ORDERED'];
const ORDER_SIMILARITY_MATCH_LIMIT = 8;

@Injectable()
export class OrdersService {
  private photoCleanupTimer: ReturnType<typeof setInterval> | null = null;
  private photoCleanupRetryRunning = false;
  private canceledOrderExpiryRunning = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly auditLog: AuditLogService,
    private readonly photoStorage: OrderPhotoStorageService,
    private readonly auditContext: AuditContextService,
    private readonly pushOutbox: PushOutboxService,
  ) {}

  onModuleInit(): void {
    const enabled =
      process.env.ORDERS_API_ENABLED?.trim().toLowerCase() === 'true';

    if (!enabled) {
      return;
    }

    void this.retryPhotoCleanupBatch();
    void this.expireCanceledOrdersBatch();

    this.photoCleanupTimer = setInterval(() => {
      void this.retryPhotoCleanupBatch();
      void this.expireCanceledOrdersBatch();
    }, PHOTO_CLEANUP_RETRY_MS);
  }

  onModuleDestroy(): void {
    if (this.photoCleanupTimer != null) {
      clearInterval(this.photoCleanupTimer);
      this.photoCleanupTimer = null;
    }
  }

  async checkDuplicate(dto: CheckOrderDuplicateDto) {
    const normalizedItemText = this.normalizeItemText(dto.itemText);

    const matches = await this.findDuplicateMatches(
      dto.category,
      normalizedItemText,
    );

    return {
      found: matches.length > 0,
      normalizedItemText,
      matches,
    };
  }

  async create(dto: CreateOrderRequestDto) {
    const actor = this.requireAuthenticatedActor();

    const requestedId = dto.id?.trim() || undefined;

    const normalizedItemText = this.normalizeItemText(dto.itemText);

    if (requestedId != null) {
      const existing = await this.prisma.orderRequest.findUnique({
        where: {
          id: requestedId,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (existing != null) {
        this.assertCanAccessOrder(existing, actor);

        return {
          order: existing,
          duplicateWarning: {
            found: existing.possibleDuplicate,
            matches: [],
          },
        };
      }
    }

    const duplicateMatches = await this.findDuplicateMatches(
      dto.category,
      normalizedItemText,
    );

    const data = {
      category: dto.category,
      itemText: dto.itemText.trim(),
      normalizedItemText,
      requestedQuantity: dto.requestedQuantity ?? null,
      suggestedCompanyText: this.trimOrNull(dto.suggestedCompanyText),
      notes: this.trimOrNull(dto.notes),
      status: 'PENDING',
      possibleDuplicate: duplicateMatches.length > 0,
      requestedByName: actor.displayName,
      requestedByUserId: actor.userId,
    };

    const order = await this.prisma.$transaction(async (tx) => {
      const created = await tx.orderRequest.create({
        data: {
          ...(requestedId == null
            ? {}
            : {
                id: requestedId,
              }),
          ...data,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      await this.auditLog.record(
        {
          action: 'CREATE',
          entityType: 'ORDER_REQUEST',
          entityId: created.id,
          after: created,
        },
        tx,
      );

      await this.pushOutbox.enqueueOrderCreated(created, tx);

      return created;
    });

    return {
      order,
      duplicateWarning: {
        found: duplicateMatches.length > 0,
        matches: duplicateMatches,
      },
    };
  }

  async preparePhotoUpload(id: string, dto: PrepareOrderPhotoDto) {
    const actor = this.requireAuthenticatedActor();
    const order = await this.requireOrder(id);

    this.assertCanAccessOrder(order, actor);

    if (order.status !== 'PENDING') {
      throw new BadRequestException(
        'Photo can only be attached while the order is PENDING.',
      );
    }

    return this.photoStorage.createUploadUrl({
      orderId: id,
      mimeType: dto.mimeType,
      fileSize: dto.fileSize,
    });
  }

  async confirmPhotoUpload(id: string, dto: ConfirmOrderPhotoDto) {
    const actor = this.requireAuthenticatedActor();
    const order = await this.requireOrder(id);

    this.assertCanAccessOrder(order, actor);

    if (order.status !== 'PENDING') {
      throw new BadRequestException(
        'Photo can only be attached while the order is PENDING.',
      );
    }

    const storageKey = await this.photoStorage.verifyUploadedObject({
      orderId: id,
      mimeType: dto.mimeType,
      fileSize: dto.fileSize,
    });

    return this.attachPhotoMetadata({
      id,
      order,
      actor,
      storageKey,
      fileSize: dto.fileSize,
      sha256: dto.sha256,
    });
  }

  async uploadWebPhoto(id: string, dto: UploadWebOrderPhotoDto) {
    const actor = this.requireAuthenticatedActor();
    const order = await this.requireOrder(id);

    this.assertCanAccessOrder(order, actor);

    if (order.status !== 'PENDING') {
      throw new BadRequestException(
        'Photo can only be attached while the order is PENDING.',
      );
    }

    const bytes = Buffer.from(dto.imageBase64, 'base64');

    if (bytes.length !== dto.fileSize) {
      throw new BadRequestException(
        'Order photo byte length does not match the declared file size.',
      );
    }

    if (
      bytes.length < 3 ||
      bytes[0] !== 0xff ||
      bytes[1] !== 0xd8 ||
      bytes[2] !== 0xff
    ) {
      throw new BadRequestException('Order photo must be a valid JPEG file.');
    }

    const actualSha256 = createHash('sha256').update(bytes).digest('hex');

    if (actualSha256 !== dto.sha256.toLowerCase()) {
      throw new BadRequestException('Order photo SHA256 does not match.');
    }

    const storageKey = await this.photoStorage.uploadBytes(
      {
        orderId: id,
        mimeType: dto.mimeType,
        fileSize: dto.fileSize,
      },
      bytes,
    );

    return this.attachPhotoMetadata({
      id,
      order,
      actor,
      storageKey,
      fileSize: dto.fileSize,
      sha256: actualSha256,
    });
  }

  private async attachPhotoMetadata(input: {
    id: string;
    order: unknown;
    actor: AuthenticatedOrderActor;
    storageKey: string;
    fileSize: number;
    sha256: string;
  }) {
    const { id, order, actor, storageKey, fileSize, sha256 } = input;

    try {
      return await this.prisma.$transaction(async (tx) => {
        const changed = await tx.orderRequest.updateMany({
          where: {
            id,
            status: 'PENDING',
            ...(actor.role === 'STAFF'
              ? {
                  requestedByUserId: actor.userId,
                }
              : {}),
          },
          data: {
            photoStorageKey: storageKey,
            photoFileSize: fileSize,
            photoSha256: sha256.toLowerCase(),
            photoDeletedAt: null,
          },
        });

        if (changed.count !== 1) {
          throw new BadRequestException(
            'Order is no longer PENDING; photo was not attached.',
          );
        }

        const updated = await tx.orderRequest.findUnique({
          where: {
            id,
          },
          include: {
            assignedCompany: {
              select: {
                id: true,
                name: true,
              },
            },
          },
        });

        if (updated == null) {
          throw new NotFoundException('Order request not found.');
        }

        await this.auditLog.record(
          {
            action: 'PHOTO_ATTACHED',
            entityType: 'ORDER_REQUEST',
            entityId: updated.id,
            before: order,
            after: updated,
          },
          tx,
        );

        return updated;
      });
    } catch (error) {
      await this.deleteStorageObjectBestEffort(storageKey);
      throw error;
    }
  }

  async createPhotoDownload(id: string) {
    const actor = this.requireAuthenticatedActor();
    const order = await this.requireOrder(id);

    this.assertCanAccessOrder(order, actor);

    if (order.status !== 'PENDING') {
      throw new NotFoundException('Order photo not found.');
    }

    const storageKey = order.photoStorageKey?.trim();

    if (!storageKey) {
      throw new NotFoundException('Order photo not found.');
    }

    const prepared = await this.photoStorage.createDownloadUrl(storageKey);

    return {
      orderId: order.id,
      fileSize: order.photoFileSize,
      sha256: order.photoSha256,
      downloadUrl: prepared.downloadUrl,
      expiresInSeconds: prepared.expiresInSeconds,
    };
  }
  async findAll(query: OrderListQuery) {
    const actor = this.requireAuthenticatedActor();

    const status = this.normalizeOptionalStatus(query.status);

    const category = this.normalizeOptionalCategory(query.category);

    if (
      actor.role === 'STAFF' &&
      status != null &&
      !ACTIVE_STAFF_DASHBOARD_STATUSES.includes(status)
    ) {
      throw new ForbiddenException(
        'Staff can only list active PENDING or ORDERED requests.',
      );
    }

    const statusWhere: Prisma.OrderRequestWhereInput =
      actor.role === 'STAFF'
        ? status == null
          ? {
              status: {
                in: ACTIVE_STAFF_DASHBOARD_STATUSES,
              },
            }
          : {
              status,
            }
        : status == null
          ? {
              status: {
                not: 'DELETED',
              },
            }
          : {
              status,
            };

    const where: Prisma.OrderRequestWhereInput = {
      ...statusWhere,
      ...(category == null
        ? {}
        : {
            category,
          }),
    };

    return this.prisma.orderRequest.findMany({
      where,
      include: {
        assignedCompany: {
          select: {
            id: true,
            name: true,
          },
        },
      },
      orderBy: [
        {
          createdAt: 'desc',
        },
        {
          id: 'desc',
        },
      ],
    });
  }

  async findChanges(query: OrderChangesQuery) {
    const actor = this.requireAuthenticatedActor();

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

    const cursorWhere: Prisma.OrderRequestWhereInput | undefined =
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

    const where: Prisma.OrderRequestWhereInput = {
      ...(actor.role === 'STAFF'
        ? {
            requestedByUserId: actor.userId,
          }
        : {}),
      ...(cursorWhere ?? {}),
    };

    const rows = await this.prisma.orderRequest.findMany({
      where,
      include: {
        assignedCompany: {
          select: {
            id: true,
            name: true,
          },
        },
      },
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
    const actor = this.requireAuthenticatedActor();

    const order = await this.prisma.orderRequest.findFirst({
      where: {
        id,
        status: {
          not: 'DELETED',
        },
      },
      include: {
        assignedCompany: {
          select: {
            id: true,
            name: true,
          },
        },
      },
    });

    if (order == null) {
      throw new NotFoundException('Order request not found.');
    }

    this.assertCanAccessOrder(order, actor);

    return order;
  }

  async updateCategory(id: string, dto: UpdateOrderCategoryDto) {
    const actor = this.requireAuthenticatedActor();

    const existing = await this.requireOrder(id);

    this.assertCanAccessOrder(existing, actor);

    if (existing.category === dto.category) {
      return existing;
    }

    const duplicateMatches = await this.findDuplicateMatches(
      dto.category,
      existing.normalizedItemText,
    );

    const possibleDuplicate = duplicateMatches.some((match) => match.id !== id);

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.orderRequest.findUnique({
        where: {
          id,
        },
      });

      const updated = await tx.orderRequest.update({
        where: {
          id,
        },
        data: {
          category: dto.category,
          possibleDuplicate,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      await this.auditLog.record(
        {
          action: 'CATEGORY_UPDATED',
          entityType: 'ORDER_REQUEST',
          entityId: updated.id,
          before: previous,
          after: updated,
        },
        tx,
      );

      return updated;
    });
  }
  async updatePending(id: string, dto: UpdatePendingOrderRequestDto) {
    this.requireAuthenticatedActor();
    const existing = await this.requireOrder(id);

    if (existing.status !== 'PENDING') {
      throw new BadRequestException('Only PENDING orders can be edited.');
    }

    const normalizedItemText = this.normalizeItemText(dto.itemText);

    const duplicateMatches = await this.findDuplicateMatches(
      dto.category,
      normalizedItemText,
    );

    const possibleDuplicate = duplicateMatches.some((match) => match.id !== id);

    return this.prisma.$transaction(async (tx) => {
      const previous = await tx.orderRequest.findUnique({
        where: {
          id,
        },
      });

      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: 'PENDING',
        },
        data: {
          category: dto.category,
          itemText: dto.itemText.trim(),
          normalizedItemText,
          requestedQuantity: dto.requestedQuantity ?? null,
          suggestedCompanyText: this.trimOrNull(dto.suggestedCompanyText),
          notes: this.trimOrNull(dto.notes),
          possibleDuplicate,
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before edit. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'ORDER_UPDATED',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: previous,
          after: current,
        },
        tx,
      );

      return current;
    });
  }

  async assign(id: string, dto: AssignOrderRequestDto) {
    const actor = this.requireAuthenticatedActor();

    this.assertManager(actor);

    const existing = await this.requireOrder(id);

    if (existing.status !== 'PENDING') {
      throw new BadRequestException(
        'Only PENDING orders can be assigned to a company.',
      );
    }

    const company = await this.prisma.company.findFirst({
      where: {
        id: dto.companyId,
        deletedAt: null,
        archivedAt: null,
      },
      select: {
        id: true,
        name: true,
      },
    });

    if (company == null) {
      throw new NotFoundException('Active company not found.');
    }

    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: 'PENDING',
        },
        data: {
          assignedCompanyId: company.id,
          orderedQuantity: dto.quantity ?? existing.requestedQuantity ?? null,
          status: 'ORDERED',
          orderedAt: now,
          orderedByName: actor.displayName,
          orderedByUserId: actor.userId,
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before assignment. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'ORDER_ASSIGNED',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: existing,
          after: current,
        },
        tx,
      );

      return current;
    });

    await this.tryCleanupPhoto(updated.id);

    return updated;
  }

  async returnToPending(id: string) {
    const actor = this.requireAuthenticatedActor();

    this.assertManager(actor);

    const existing = await this.requireOrder(id);

    if (existing.status !== 'ORDERED') {
      throw new BadRequestException(
        'Only ORDERED orders can be returned to PENDING.',
      );
    }

    return this.prisma.$transaction(async (tx) => {
      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: 'ORDERED',
        },
        data: {
          status: 'PENDING',
          assignedCompanyId: null,
          orderedQuantity: null,
          orderedAt: null,
          orderedByName: null,
          orderedByUserId: null,
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before it could be returned. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'ORDER_RETURNED_TO_PENDING',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: existing,
          after: current,
        },
        tx,
      );

      return current;
    });
  }

  async receive(id: string) {
    const actor = this.requireAuthenticatedActor();

    const existing = await this.requireOrder(id);

    if (existing.status !== 'ORDERED') {
      throw new BadRequestException('Only ORDERED orders can be received.');
    }

    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: 'ORDERED',
        },
        data: {
          status: 'RECEIVED',
          receivedAt: now,
          receivedByName: actor.displayName,
          receivedByUserId: actor.userId,
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before receipt confirmation. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'RECEIVE',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: existing,
          after: current,
        },
        tx,
      );

      return current;
    });

    await this.tryCleanupPhoto(updated.id);

    return updated;
  }

  async cancel(id: string) {
    const actor = this.requireAuthenticatedActor();

    this.assertManager(actor);

    const existing = await this.requireOrder(id);

    if (existing.status !== 'PENDING' && existing.status !== 'ORDERED') {
      throw new BadRequestException(
        'Only PENDING or ORDERED orders can be canceled.',
      );
    }

    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: existing.status,
        },
        data: {
          status: 'CANCELED',
          canceledAt: now,
          canceledByName: actor.displayName,
          canceledByUserId: actor.userId,
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before cancellation. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'CANCEL',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: existing,
          after: current,
        },
        tx,
      );

      return current;
    });

    await this.tryCleanupPhoto(updated.id);

    return updated;
  }

  async restoreCanceled(id: string) {
    const actor = this.requireAuthenticatedActor();

    this.assertManager(actor);

    const existing = await this.requireOrder(id);

    if (existing.status !== 'CANCELED') {
      throw new BadRequestException(
        'Only CANCELED orders can be restored.',
      );
    }

    if (existing.canceledAt == null) {
      throw new BadRequestException(
        'Canceled order has no cancellation timestamp.',
      );
    }

    const now = new Date();

    if (
      now.getTime() - existing.canceledAt.getTime() >=
      CANCELED_ORDER_RETENTION_MS
    ) {
      throw new BadRequestException(
        'Canceled order restore window has expired.',
      );
    }

    const restoreToOrdered = existing.orderedAt != null;

    return this.prisma.$transaction(async (tx) => {
      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: 'CANCELED',
        },
        data: {
          status: restoreToOrdered ? 'ORDERED' : 'PENDING',
          canceledAt: null,
          canceledByName: null,
          canceledByUserId: null,
          ...(restoreToOrdered
            ? {}
            : {
                assignedCompanyId: null,
                orderedQuantity: null,
                orderedAt: null,
                orderedByName: null,
                orderedByUserId: null,
              }),
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before restore. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
        include: {
          assignedCompany: {
            select: {
              id: true,
              name: true,
            },
          },
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'ORDER_RESTORED_FROM_CANCELED',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: existing,
          after: current,
        },
        tx,
      );

      return current;
    });
  }

  async removePending(id: string) {
    const actor = this.requireAuthenticatedActor();

    const existing = await this.requireOrder(id);

    if (existing.status !== 'PENDING') {
      throw new BadRequestException('Only PENDING orders can be deleted.');
    }

    const now = new Date();

    const updated = await this.prisma.$transaction(async (tx) => {
      const changed = await tx.orderRequest.updateMany({
        where: {
          id,
          status: 'PENDING',
        },
        data: {
          status: 'DELETED',
          deletedAt: now,
          deletedByName: actor.displayName,
          deletedByUserId: actor.userId,
        },
      });

      if (changed.count !== 1) {
        throw new BadRequestException(
          'Order status changed before deletion. Reload and try again.',
        );
      }

      const current = await tx.orderRequest.findUnique({
        where: {
          id,
        },
      });

      if (current == null) {
        throw new NotFoundException('Order request not found.');
      }

      await this.auditLog.record(
        {
          action: 'DELETE',
          entityType: 'ORDER_REQUEST',
          entityId: current.id,
          before: existing,
          after: current,
        },
        tx,
      );

      return current;
    });

    await this.tryCleanupPhoto(updated.id);

    return updated;
  }

  async expireCanceledOrdersBatch(now = new Date()): Promise<number> {
    if (this.canceledOrderExpiryRunning) {
      return 0;
    }

    this.canceledOrderExpiryRunning = true;

    try {
      const cutoff = new Date(
        now.getTime() - CANCELED_ORDER_RETENTION_MS,
      );

      const stale = await this.prisma.orderRequest.findMany({
        where: {
          status: 'CANCELED',
          canceledAt: {
            lte: cutoff,
          },
        },
        orderBy: [
          {
            canceledAt: 'asc',
          },
          {
            id: 'asc',
          },
        ],
        take: CANCELED_ORDER_EXPIRY_BATCH_SIZE,
      });

      let expiredCount = 0;

      for (const existing of stale) {
        try {
          const expired = await this.prisma.$transaction(async (tx) => {
            const changed = await tx.orderRequest.updateMany({
              where: {
                id: existing.id,
                status: 'CANCELED',
                canceledAt: {
                  lte: cutoff,
                },
              },
              data: {
                status: 'DELETED',
                deletedAt: now,
                deletedByName: 'SYSTEM',
                deletedByUserId: null,
              },
            });

            if (changed.count !== 1) {
              return false;
            }

            const current = await tx.orderRequest.findUnique({
              where: {
                id: existing.id,
              },
            });

            if (current == null) {
              return false;
            }

            await this.auditLog.record(
              {
                action: 'AUTO_DELETE_CANCELED_ORDER',
                entityType: 'ORDER_REQUEST',
                entityId: current.id,
                before: existing,
                after: current,
              },
              tx,
            );

            return true;
          });

          if (expired) {
            expiredCount += 1;
          }
        } catch {
          console.warn(
            '[Orders] Automatic expiry failed for canceled order ' +
              existing.id +
              '.',
          );
        }
      }

      return expiredCount;
    } catch {
      console.warn('[Orders] Background canceled-order expiry batch failed.');
      return 0;
    } finally {
      this.canceledOrderExpiryRunning = false;
    }
  }

  private async tryCleanupPhoto(orderId: string): Promise<boolean> {
    try {
      const order = await this.prisma.orderRequest.findUnique({
        where: {
          id: orderId,
        },
        select: {
          id: true,
          status: true,
          photoStorageKey: true,
          photoDeletedAt: true,
        },
      });

      if (order == null) {
        return true;
      }

      const storageKey = order.photoStorageKey?.trim();

      if (!storageKey || order.photoDeletedAt != null) {
        return true;
      }

      if (!PHOTO_CLEANUP_STATUSES.includes(order.status)) {
        return false;
      }

      await this.photoStorage.deleteObject(storageKey);

      const cleaned = await this.prisma.orderRequest.updateMany({
        where: {
          id: order.id,
          status: {
            in: PHOTO_CLEANUP_STATUSES,
          },
          photoStorageKey: storageKey,
          photoDeletedAt: null,
        },
        data: {
          photoStorageKey: null,
          photoFileSize: null,
          photoSha256: null,
          photoDeletedAt: new Date(),
        },
      });

      return cleaned.count === 1;
    } catch {
      console.warn(
        '[Orders] Best-effort photo cleanup failed for order ' + orderId + '.',
      );

      return false;
    }
  }

  private async retryPhotoCleanupBatch(): Promise<void> {
    if (this.photoCleanupRetryRunning) {
      return;
    }

    this.photoCleanupRetryRunning = true;

    try {
      const stale = await this.prisma.orderRequest.findMany({
        where: {
          status: {
            in: PHOTO_CLEANUP_STATUSES,
          },
          photoStorageKey: {
            not: null,
          },
          photoDeletedAt: null,
        },
        select: {
          id: true,
        },
        orderBy: [
          {
            updatedAt: 'asc',
          },
          {
            id: 'asc',
          },
        ],
        take: PHOTO_CLEANUP_BATCH_SIZE,
      });

      for (const item of stale) {
        await this.tryCleanupPhoto(item.id);
      }
    } catch {
      console.warn('[Orders] Background photo cleanup batch failed.');
    } finally {
      this.photoCleanupRetryRunning = false;
    }
  }

  private async deleteStorageObjectBestEffort(
    storageKey: string,
  ): Promise<void> {
    try {
      await this.photoStorage.deleteObject(storageKey);
    } catch {
      console.warn(
        '[Orders] Best-effort cleanup of an unattached photo object failed.',
      );
    }
  }
  private async requireOrder(id: string) {
    const order = await this.prisma.orderRequest.findFirst({
      where: {
        id,
        status: {
          not: 'DELETED',
        },
      },
    });

    if (order == null) {
      throw new NotFoundException('Order request not found.');
    }

    return order;
  }

  private async findDuplicateMatches(
    category: string,
    normalizedItemText: string,
  ) {
    const candidates = await this.prisma.orderRequest.findMany({
      where: {
        category,
        status: {
          in: ['PENDING', 'ORDERED'],
        },
      },
      select: {
        id: true,
        category: true,
        itemText: true,
        requestedQuantity: true,
        orderedQuantity: true,
        status: true,
        requestedByName: true,
        createdAt: true,
        assignedCompany: {
          select: {
            id: true,
            name: true,
          },
        },
      },
      orderBy: [
        {
          createdAt: 'desc',
        },
        {
          id: 'desc',
        },
      ],
    });

    return candidates
      .filter(
        (candidate) =>
          ACTIVE_DUPLICATE_STATUSES.has(candidate.status) &&
          isOrderTextSimilar(normalizedItemText, candidate.itemText),
      )
      .map((candidate) => ({
        candidate,
        similarityScore: scoreOrderTextSimilarity(
          normalizedItemText,
          candidate.itemText,
        ),
      }))
      .sort((left, right) => right.similarityScore - left.similarityScore)
      .slice(0, ORDER_SIMILARITY_MATCH_LIMIT)
      .map(({ candidate, similarityScore }) => ({
        ...candidate,
        similarityScore: Number(similarityScore.toFixed(4)),
      }));
  }

  private normalizeItemText(raw: string) {
    const normalized = normalizeOrderSearchText(raw);

    if (normalized.length === 0) {
      throw new BadRequestException(
        'itemText cannot be empty after normalization.',
      );
    }

    return normalized;
  }

  private requireAuthenticatedActor(): AuthenticatedOrderActor {
    const context = this.auditContext.get();

    if (
      context == null ||
      !context.actorVerified ||
      !context.actorUserId ||
      !context.actorDisplayName ||
      (context.actorRole !== 'MANAGER' && context.actorRole !== 'STAFF')
    ) {
      throw new UnauthorizedException(
        'A verified authenticated user is required for Orders.',
      );
    }

    return {
      userId: context.actorUserId,
      displayName: context.actorDisplayName,
      role: context.actorRole,
    };
  }

  private assertManager(actor: AuthenticatedOrderActor): void {
    if (actor.role !== 'MANAGER') {
      throw new ForbiddenException(
        'Only a MANAGER can perform this operation.',
      );
    }
  }

  private assertCanAccessOrder(
    order: {
      requestedByUserId: string | null;
    },
    actor: AuthenticatedOrderActor,
  ): void {
    if (actor.role === 'MANAGER') {
      return;
    }

    if (order.requestedByUserId !== actor.userId) {
      throw new ForbiddenException('This order belongs to another user.');
    }
  }

  private trimOrNull(raw?: string | null) {
    if (raw == null) {
      return null;
    }

    const value = raw.trim();

    return value.length === 0 ? null : value;
  }

  private normalizeOptionalStatus(raw?: string) {
    const value = raw?.trim().toUpperCase();

    if (!value) {
      return undefined;
    }

    if (!VALID_STATUSES.has(value)) {
      throw new BadRequestException('Invalid order status.');
    }

    return value;
  }

  private normalizeOptionalCategory(raw?: string) {
    const value = raw?.trim().toUpperCase();

    if (!value) {
      return undefined;
    }

    if (!VALID_CATEGORIES.has(value)) {
      throw new BadRequestException('Invalid order category.');
    }

    return value;
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
