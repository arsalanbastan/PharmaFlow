import { CashPaymentsService } from './cash-payments.service';
import { CreateCashPaymentDto } from './dto/create-cash-payment.dto';
import { UpdateCashPaymentDto } from './dto/update-cash-payment.dto';
export declare class CashPaymentsController {
    private readonly cashPaymentsService;
    constructor(cashPaymentsService: CashPaymentsService);
    create(createCashPaymentDto: CreateCashPaymentDto): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        amount: import("@prisma/client/runtime/library").Decimal;
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
        amount: import("@prisma/client/runtime/library").Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    }[]>;
    findChanges(updatedAfter?: string, afterId?: string, limit?: string): Promise<{
        items: {
            id: string;
            notes: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
            companyId: string;
            amount: import("@prisma/client/runtime/library").Decimal;
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
        amount: import("@prisma/client/runtime/library").Decimal;
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
        amount: import("@prisma/client/runtime/library").Decimal;
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
        amount: import("@prisma/client/runtime/library").Decimal;
        bankAccountId: string;
        description: string | null;
        paymentDate: Date;
        paymentMethod: string;
        trackingNumber: string | null;
    }>;
}
