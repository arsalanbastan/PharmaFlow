import { PrismaService } from '../database/prisma/prisma.service';
import { AuditLogService } from '../audit/audit-log.service';
import { CreateBankAccountDto } from './dto/create-bank-account.dto';
import { UpdateBankAccountDto } from './dto/update-bank-account.dto';
type BankAccountChangesQuery = {
    updatedAfter?: string;
    afterId?: string;
    limit?: string;
};
export declare class BankAccountsService {
    private readonly prisma;
    private readonly auditLog;
    constructor(prisma: PrismaService, auditLog: AuditLogService);
    create(createBankAccountDto: CreateBankAccountDto): Promise<{
        id: string;
        bankName: string;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        accountTitle: string | null;
        accountHolder: string | null;
    }>;
    findAll(): Promise<{
        id: string;
        bankName: string;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        accountTitle: string | null;
        accountHolder: string | null;
    }[]>;
    findChanges(query: BankAccountChangesQuery): Promise<{
        items: {
            id: string;
            bankName: string;
            accountNumber: string | null;
            cardNumber: string | null;
            shebaNumber: string | null;
            notes: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
            accountTitle: string | null;
            accountHolder: string | null;
        }[];
        hasMore: boolean;
        nextCursor: {
            updatedAt: string;
            id: string;
        } | null;
    }>;
    findOne(id: string): Promise<{
        id: string;
        bankName: string;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        accountTitle: string | null;
        accountHolder: string | null;
    } | null>;
    update(id: string, updateBankAccountDto: UpdateBankAccountDto): Promise<{
        id: string;
        bankName: string;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        accountTitle: string | null;
        accountHolder: string | null;
    }>;
    remove(id: string): Promise<{
        id: string;
        bankName: string;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        accountTitle: string | null;
        accountHolder: string | null;
    }>;
    private parseChangesLimit;
}
export {};
