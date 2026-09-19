import { Prisma } from '@prisma/client';
import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { CreateCashPaymentDto } from './dto/create-cash-payment.dto';
import { UpdateCashPaymentDto } from './dto/update-cash-payment.dto';
type CashPaymentChangesQuery = {
    updatedAfter?: string;
    afterId?: string;
    limit?: string;
};
export declare class CashPaymentsService {
    private readonly prisma;
    private readonly auditLog;
    constructor(prisma: PrismaService, auditLog: AuditLogService);
    create(createCashPaymentDto: CreateCashPaymentDto): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        amount: Prisma.Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    }>;
    findAll(): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        amount: Prisma.Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    }[]>;
    findChanges(query: CashPaymentChangesQuery): Promise<{
        items: {
            id: string;
            notes: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
            companyId: string;
            amount: Prisma.Decimal;
            bankAccountId: string;
            description: string | null;
            paymentDate: Date;
            paymentMethod: string;
            trackingNumber: string | null;
        }[];
        hasMore: boolean;
        nextCursor: {
            updatedAt: string;
            id: string;
        } | null;
    }>;
    findOne(id: string): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        amount: Prisma.Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    } | null>;
    update(id: string, updateCashPaymentDto: UpdateCashPaymentDto): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        amount: Prisma.Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    }>;
    remove(id: string): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        amount: Prisma.Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    }>;
    private parseChangesLimit;
}
export {};
