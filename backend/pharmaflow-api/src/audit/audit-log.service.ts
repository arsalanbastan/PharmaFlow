import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../database/prisma/prisma.service';
import { AuditContextService } from './audit-context.service';

type AuditDatabase = Pick<Prisma.TransactionClient, 'auditLog'>;

export type AuditMutationInput = {
  action: string;
  entityType: string;
  entityId?: string | null;
  before?: unknown;
  after?: unknown;
};

@Injectable()
export class AuditLogService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly context: AuditContextService,
  ) {}

  async record(input: AuditMutationInput, database?: AuditDatabase) {
    const requestContext = this.context.get();

    const db: AuditDatabase = database ?? this.prisma;

    const beforeData = this.sanitize(input.before);
    const afterData = this.sanitize(input.after);

    return db.auditLog.create({
      data: {
        source: requestContext?.source ?? 'SYSTEM',

        actorDisplayName: this.cleanText(requestContext?.actorDisplayName, 160),

        actorUserId: requestContext?.actorUserId ?? null,

        actorVerified: requestContext?.actorVerified ?? false,

        deviceId: this.cleanText(requestContext?.deviceId, 200),

        action: input.action,

        entityType: input.entityType,

        entityId: this.cleanText(input.entityId ?? undefined, 200),

        ...(beforeData !== undefined ? { beforeData } : {}),

        ...(afterData !== undefined ? { afterData } : {}),

        ipAddress: this.cleanText(requestContext?.ipAddress, 200),

        requestId: this.cleanText(requestContext?.requestId, 200),
      },
    });
  }

  async findRecent(query = '') {
    const rows = await this.prisma.auditLog.findMany({
      orderBy: {
        createdAt: 'desc',
      },
      take: 500,
    });

    const q = query.trim().toLowerCase();

    if (!q) {
      return rows;
    }

    return rows.filter((item) =>
      [
        item.source,
        item.actorDisplayName,
        item.deviceId,
        item.action,
        item.entityType,
        item.entityId,
        item.ipAddress,
        item.requestId,
      ].some((value) =>
        String(value ?? '')
          .toLowerCase()
          .includes(q),
      ),
    );
  }

  private cleanText(
    value: string | undefined,
    maxLength: number,
  ): string | null {
    const text = String(value ?? '').trim();

    if (!text) {
      return null;
    }

    return text.slice(0, maxLength);
  }

  private sanitize(value: unknown): Prisma.InputJsonValue | undefined {
    if (value === undefined || value === null) {
      return undefined;
    }

    const json = JSON.stringify(value, (key, item) => {
      const normalizedKey = String(key).toLowerCase();

      if (
        normalizedKey.includes('password') ||
        normalizedKey.includes('token') ||
        normalizedKey.includes('secret')
      ) {
        return '[REDACTED]';
      }

      if (key === 'imageData') {
        if (item == null || item === '') {
          return null;
        }

        return {
          present: true,
          length: String(item).length,
        };
      }

      if (typeof item === 'bigint') {
        return item.toString();
      }

      return item;
    });

    if (!json) {
      return undefined;
    }

    return JSON.parse(json) as Prisma.InputJsonValue;
  }
}
