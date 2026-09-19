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
export declare class AuditLogService {
    private readonly prisma;
    private readonly context;
    constructor(prisma: PrismaService, context: AuditContextService);
    record(input: AuditMutationInput, database?: AuditDatabase): Promise<{
        id: string;
        createdAt: Date;
        source: string;
        actorDisplayName: string | null;
        actorUserId: string | null;
        actorVerified: boolean;
        deviceId: string | null;
        action: string;
        entityType: string;
        entityId: string | null;
        beforeData: Prisma.JsonValue | null;
        afterData: Prisma.JsonValue | null;
        ipAddress: string | null;
        requestId: string | null;
    }>;
    findRecent(query?: string): Promise<{
        id: string;
        createdAt: Date;
        source: string;
        actorDisplayName: string | null;
        actorUserId: string | null;
        actorVerified: boolean;
        deviceId: string | null;
        action: string;
        entityType: string;
        entityId: string | null;
        beforeData: Prisma.JsonValue | null;
        afterData: Prisma.JsonValue | null;
        ipAddress: string | null;
        requestId: string | null;
    }[]>;
    private cleanText;
    private sanitize;
}
export {};
