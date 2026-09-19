import { Prisma } from '@prisma/client';
import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
type FormBody = Record<string, string | undefined>;
type InvoiceListFilters = {
    invoiceNumber?: string;
    companyId?: string;
    docType?: string;
    dateFrom?: string;
    dateTo?: string;
    page?: string;
    pageSize?: string;
};
type CatalogListFilters = {
    q?: string;
    category?: string;
    active?: string;
    shape?: string;
    sort?: string;
    page?: string;
    pageSize?: string;
};
export declare class AdminService {
    private readonly prisma;
    private readonly auditLog;
    constructor(prisma: PrismaService, auditLog: AuditLogService);
    dashboard(): Promise<{
        companies: number;
        bankAccounts: number;
        cheques: number;
        cashPayments: number;
        users: number;
        orders: number;
        pendingOrders: number;
        auditLogs: number;
        catalogItems: number;
    }>;
    catalog(filters?: CatalogListFilters): Promise<{
        items: {
            id: string;
            description: string | null;
            isActive: boolean;
            category: string;
            ingestSequence: bigint;
            arsenDrugId: bigint;
            persianName: string | null;
            genericName: string | null;
            persianBrandName: string | null;
            brandName: string | null;
            unit: string | null;
            shapeName: string | null;
            packetQuantity: number | null;
            salesPrice: Prisma.Decimal | null;
            lastPurchasePrice: Prisma.Decimal | null;
            importedAt: Date;
            sourceSyncedAt: Date;
        }[];
        shapes: string[];
        stats: {
            totalItems: number;
            drugCount: number;
            goodsCount: number;
            activeCount: number;
            inactiveCount: number;
        };
        page: number;
        pageSize: number;
        totalCount: number;
        totalPages: number;
        sort: string;
    }>;
    catalogExport(filters?: CatalogListFilters): Promise<{
        description: string | null;
        isActive: boolean;
        category: string;
        arsenDrugId: bigint;
        persianName: string | null;
        genericName: string | null;
        persianBrandName: string | null;
        brandName: string | null;
        unit: string | null;
        shapeName: string | null;
        packetQuantity: number | null;
        salesPrice: Prisma.Decimal | null;
        lastPurchasePrice: Prisma.Decimal | null;
        importedAt: Date;
        sourceSyncedAt: Date;
    }[]>;
    catalogItem(id: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        description: string | null;
        isActive: boolean;
        category: string;
        ingestSequence: bigint;
        arsenDrugId: bigint;
        persianName: string | null;
        genericName: string | null;
        persianBrandName: string | null;
        brandName: string | null;
        unit: string | null;
        shapeName: string | null;
        packetQuantity: number | null;
        salesPrice: Prisma.Decimal | null;
        lastPurchasePrice: Prisma.Decimal | null;
        sourceFingerprint: string;
        importedAt: Date;
        sourceSyncedAt: Date;
    }>;
    invoices(filters?: InvoiceListFilters): Promise<{
        items: {
            paidAmount: number;
            remainingAmount: number;
            paymentStatus: string;
            company: {
                id: string;
                name: string;
            };
            id: string;
            ingestSequence: bigint;
            importedAt: Date;
            arsenFactorId: number;
            invoiceNumber: string | null;
            invoiceDate: string | null;
            settlementDate: string | null;
            factorDocType: number;
            factorDocTypeName: string | null;
            factorPayablePrice: Prisma.Decimal | null;
            paymentDays: number | null;
            isDeletedInArsen: boolean;
            itemCount: number;
            chequeAllocations: {
                amount: Prisma.Decimal;
            }[];
            cashPaymentAllocations: {
                amount: Prisma.Decimal;
            }[];
            discountAllocations: {
                amount: Prisma.Decimal;
            }[];
        }[];
        companies: {
            id: string;
            name: string;
        }[];
        page: number;
        pageSize: number;
        totalCount: number;
        totalPages: number;
    }>;
    invoiceSettlementForm(invoiceIdsText: string): Promise<{
        invoiceIds: string;
        company: {
            id: string;
            name: string;
        };
        invoices: {
            paidAmount: number;
            remainingAmount: number;
            company: {
                id: string;
                name: string;
            };
            id: string;
            invoiceNumber: string | null;
            invoiceDate: string | null;
            factorDocType: number;
            factorPayablePrice: Prisma.Decimal | null;
            isDeletedInArsen: boolean;
            chequeAllocations: {
                amount: Prisma.Decimal;
            }[];
            cashPaymentAllocations: {
                amount: Prisma.Decimal;
            }[];
            discountAllocations: {
                amount: Prisma.Decimal;
            }[];
        }[];
        total: number;
        bankAccounts: {
            id: string;
            bankName: string;
            accountTitle: string | null;
        }[];
    }>;
    settleInvoices(kind: 'CHEQUE' | 'CASH', body: FormBody): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        chequeNumber: string;
        amount: Prisma.Decimal;
        chequeDate: Date;
        dueDate: Date | null;
        status: string | null;
        bankAccountId: string;
        sayadStatus: string | null;
        isRegisteredInSayad: boolean | null;
        sayadId: string | null;
        imagePath: string | null;
        imageData: string | null;
        description: string | null;
    } | {
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
    invoicesExport(filters?: InvoiceListFilters): Promise<{
        company: {
            name: string;
        };
        description: string | null;
        importedAt: Date;
        sourceSyncedAt: Date;
        arsenFactorId: number;
        invoiceNumber: string | null;
        invoiceDate: string | null;
        settlementDate: string | null;
        factorDocType: number;
        factorDocTypeName: string | null;
        factorPayablePrice: Prisma.Decimal | null;
        paymentDays: number | null;
        isDeletedInArsen: boolean;
        itemCount: number;
    }[]>;
    invoice(id: string): Promise<{
        company: {
            id: string;
            name: string;
        };
        items: {
            id: string;
            createdAt: Date;
            updatedAt: Date;
            arsenDrugId: bigint | null;
            packetQuantity: number | null;
            invoiceId: string;
            arsenFactorDetailId: bigint;
            arsenFactorDetailsId: number | null;
            drugName: string | null;
            barcode: string | null;
            quantity: number | null;
            salePrice: Prisma.Decimal | null;
            purchasePrice: Prisma.Decimal | null;
            rowDiscount: Prisma.Decimal | null;
            hasTax: number | null;
            expireDate: string | null;
            expireDateGregorian: Date | null;
            batchNumber: string | null;
        }[];
    } & {
        id: string;
        createdAt: Date;
        updatedAt: Date;
        arsenBusinessPartnerId: number;
        companyId: string;
        description: string | null;
        ingestSequence: bigint;
        sourceFingerprint: string | null;
        importedAt: Date;
        sourceSyncedAt: Date;
        arsenFactorId: number;
        invoiceNumber: string | null;
        invoiceDate: string | null;
        docDate: string | null;
        settlementDate: string | null;
        factorDocType: number;
        factorDocTypeName: string | null;
        factorType: number | null;
        factorTypeName: string | null;
        factorItemType: string | null;
        arsenBusinessPartnerName: string;
        factorTotalPrice: Prisma.Decimal | null;
        factorDiscount: Prisma.Decimal | null;
        factorTax: Prisma.Decimal | null;
        factorPayablePrice: Prisma.Decimal | null;
        barbariPrice: Prisma.Decimal | null;
        paymentDays: number | null;
        isDeletedInArsen: boolean;
        isLockedInArsen: boolean | null;
        arsenSaveDateTime: Date | null;
        itemCount: number;
    }>;
    companies(query?: string): Promise<({
        _count: {
            cheques: number;
            orderRequests: number;
            cashPayments: number;
            arsenCompanyMappings: number;
            arsenInvoices: number;
        };
    } & {
        id: string;
        name: string;
        nationalId: string | null;
        economicCode: string | null;
        bankName: string | null;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        visitorName: string | null;
        visitorPhone: string | null;
        accountantName: string | null;
        accountantPhone: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
    })[]>;
    company(id: string): Promise<{
        _count: {
            cheques: number;
            orderRequests: number;
            cashPayments: number;
            arsenCompanyMappings: number;
            arsenInvoices: number;
        };
    } & {
        id: string;
        name: string;
        nationalId: string | null;
        economicCode: string | null;
        bankName: string | null;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        visitorName: string | null;
        visitorPhone: string | null;
        accountantName: string | null;
        accountantPhone: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
    }>;
    updateCompany(id: string, body: FormBody): Promise<{
        id: string;
        name: string;
        nationalId: string | null;
        economicCode: string | null;
        bankName: string | null;
        accountNumber: string | null;
        cardNumber: string | null;
        shebaNumber: string | null;
        notes: string | null;
        visitorName: string | null;
        visitorPhone: string | null;
        accountantName: string | null;
        accountantPhone: string | null;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
    }>;
    hardDeleteCompany(id: string): Promise<void>;
    bankAccounts(query?: string): Promise<({
        _count: {
            cheques: number;
            cashPayments: number;
        };
    } & {
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
    })[]>;
    bankAccount(id: string): Promise<{
        _count: {
            cheques: number;
            cashPayments: number;
        };
    } & {
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
    updateBankAccount(id: string, body: FormBody): Promise<{
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
    hardDeleteBankAccount(id: string): Promise<void>;
    cheques(query?: string): Promise<({
        company: {
            id: string;
            name: string;
        };
        _count: {
            attachments: number;
        };
        bankAccount: {
            id: string;
            bankName: string;
            accountTitle: string | null;
        };
    } & {
        id: string;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        chequeNumber: string;
        amount: Prisma.Decimal;
        chequeDate: Date;
        dueDate: Date | null;
        status: string | null;
        bankAccountId: string;
        sayadStatus: string | null;
        isRegisteredInSayad: boolean | null;
        sayadId: string | null;
        imagePath: string | null;
        imageData: string | null;
        description: string | null;
    })[]>;
    cheque(id: string): Promise<{
        item: {
            company: {
                id: string;
                name: string;
            };
            bankAccount: {
                id: string;
                bankName: string;
                accountTitle: string | null;
            };
            attachments: {
                id: string;
                storageKey: string;
                fileName: string;
            }[];
        } & {
            id: string;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
            companyId: string;
            chequeNumber: string;
            amount: Prisma.Decimal;
            chequeDate: Date;
            dueDate: Date | null;
            status: string | null;
            bankAccountId: string;
            sayadStatus: string | null;
            isRegisteredInSayad: boolean | null;
            sayadId: string | null;
            imagePath: string | null;
            imageData: string | null;
            description: string | null;
        };
        companies: {
            id: string;
            name: string;
            nationalId: string | null;
            economicCode: string | null;
            bankName: string | null;
            accountNumber: string | null;
            cardNumber: string | null;
            shebaNumber: string | null;
            notes: string | null;
            visitorName: string | null;
            visitorPhone: string | null;
            accountantName: string | null;
            accountantPhone: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
        }[];
        bankAccounts: {
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
    }>;
    updateCheque(id: string, body: FormBody): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        archivedAt: Date | null;
        deletedAt: Date | null;
        companyId: string;
        chequeNumber: string;
        amount: Prisma.Decimal;
        chequeDate: Date;
        dueDate: Date | null;
        status: string | null;
        bankAccountId: string;
        sayadStatus: string | null;
        isRegisteredInSayad: boolean | null;
        sayadId: string | null;
        imagePath: string | null;
        imageData: string | null;
        description: string | null;
    }>;
    hardDeleteCheque(id: string): Promise<void>;
    cashPayments(query?: string): Promise<({
        company: {
            id: string;
            name: string;
        };
        _count: {
            attachments: number;
        };
        bankAccount: {
            id: string;
            bankName: string;
            accountTitle: string | null;
        };
    } & {
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
    })[]>;
    cashPayment(id: string): Promise<{
        item: {
            company: {
                id: string;
                name: string;
            };
            bankAccount: {
                id: string;
                bankName: string;
                accountTitle: string | null;
            };
            attachments: {
                id: string;
                storageKey: string;
                fileName: string;
            }[];
        } & {
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
        };
        companies: {
            id: string;
            name: string;
            nationalId: string | null;
            economicCode: string | null;
            bankName: string | null;
            accountNumber: string | null;
            cardNumber: string | null;
            shebaNumber: string | null;
            notes: string | null;
            visitorName: string | null;
            visitorPhone: string | null;
            accountantName: string | null;
            accountantPhone: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
        }[];
        bankAccounts: {
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
    }>;
    updateCashPayment(id: string, body: FormBody): Promise<{
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
    hardDeleteCashPayment(id: string): Promise<void>;
    users(query?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        _count: {
            sessions: number;
            pushDevices: number;
        };
        username: string;
        displayName: string;
        role: string;
        managerAppAccess: boolean;
        canCreateOrders: boolean;
        canCreateCheques: boolean;
        canCreateCashPayments: boolean;
        canViewFinancialReports: boolean;
        isActive: boolean;
    }[]>;
    user(id: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        _count: {
            sessions: number;
            pushDevices: number;
        };
        username: string;
        displayName: string;
        role: string;
        managerAppAccess: boolean;
        canCreateOrders: boolean;
        canCreateCheques: boolean;
        canCreateCashPayments: boolean;
        canViewFinancialReports: boolean;
        isActive: boolean;
    }>;
    updateUser(id: string, body: FormBody): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        username: string;
        displayName: string;
        role: string;
        managerAppAccess: boolean;
        canCreateOrders: boolean;
        canCreateCheques: boolean;
        canCreateCashPayments: boolean;
        canViewFinancialReports: boolean;
        isActive: boolean;
        passwordHash: string;
    }>;
    hardDeleteUser(id: string): Promise<void>;
    orders(query?: string, status?: string): Promise<({
        assignedCompany: {
            id: string;
            name: string;
        } | null;
    } & {
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        status: string;
        itemText: string;
        requestedByName: string;
        category: string;
        normalizedItemText: string;
        requestedQuantity: number | null;
        orderedQuantity: number | null;
        suggestedCompanyText: string | null;
        possibleDuplicate: boolean;
        assignedCompanyId: string | null;
        orderedByName: string | null;
        receivedByName: string | null;
        canceledByName: string | null;
        deletedByName: string | null;
        requestedByUserId: string | null;
        orderedByUserId: string | null;
        receivedByUserId: string | null;
        canceledByUserId: string | null;
        deletedByUserId: string | null;
        orderedAt: Date | null;
        receivedAt: Date | null;
        canceledAt: Date | null;
        photoStorageKey: string | null;
        photoFileSize: number | null;
        photoSha256: string | null;
        photoDeletedAt: Date | null;
    })[]>;
    order(id: string): Promise<{
        item: {
            assignedCompany: {
                id: string;
                name: string;
            } | null;
        } & {
            id: string;
            notes: string | null;
            createdAt: Date;
            updatedAt: Date;
            deletedAt: Date | null;
            status: string;
            itemText: string;
            requestedByName: string;
            category: string;
            normalizedItemText: string;
            requestedQuantity: number | null;
            orderedQuantity: number | null;
            suggestedCompanyText: string | null;
            possibleDuplicate: boolean;
            assignedCompanyId: string | null;
            orderedByName: string | null;
            receivedByName: string | null;
            canceledByName: string | null;
            deletedByName: string | null;
            requestedByUserId: string | null;
            orderedByUserId: string | null;
            receivedByUserId: string | null;
            canceledByUserId: string | null;
            deletedByUserId: string | null;
            orderedAt: Date | null;
            receivedAt: Date | null;
            canceledAt: Date | null;
            photoStorageKey: string | null;
            photoFileSize: number | null;
            photoSha256: string | null;
            photoDeletedAt: Date | null;
        };
        companies: {
            id: string;
            name: string;
            nationalId: string | null;
            economicCode: string | null;
            bankName: string | null;
            accountNumber: string | null;
            cardNumber: string | null;
            shebaNumber: string | null;
            notes: string | null;
            visitorName: string | null;
            visitorPhone: string | null;
            accountantName: string | null;
            accountantPhone: string | null;
            createdAt: Date;
            updatedAt: Date;
            archivedAt: Date | null;
            deletedAt: Date | null;
        }[];
    }>;
    updateOrder(id: string, body: FormBody): Promise<{
        id: string;
        notes: string | null;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        status: string;
        itemText: string;
        requestedByName: string;
        category: string;
        normalizedItemText: string;
        requestedQuantity: number | null;
        orderedQuantity: number | null;
        suggestedCompanyText: string | null;
        possibleDuplicate: boolean;
        assignedCompanyId: string | null;
        orderedByName: string | null;
        receivedByName: string | null;
        canceledByName: string | null;
        deletedByName: string | null;
        requestedByUserId: string | null;
        orderedByUserId: string | null;
        receivedByUserId: string | null;
        canceledByUserId: string | null;
        deletedByUserId: string | null;
        orderedAt: Date | null;
        receivedAt: Date | null;
        canceledAt: Date | null;
        photoStorageKey: string | null;
        photoFileSize: number | null;
        photoSha256: string | null;
        photoDeletedAt: Date | null;
    }>;
    hardDeleteOrder(id: string): Promise<void>;
    auditLogs(query?: string): Promise<{
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
    hardDeleteAuditLog(id: string): Promise<void>;
    private filter;
    private jalaliDate;
    private positiveInteger;
    private catalogQuery;
    private invoiceWhere;
    private invoiceIds;
    private catalogPageSize;
    private catalogSearchVariants;
    private catalogOrderBy;
    private invoicePageSize;
    private required;
    private nullable;
    private oneOf;
    private positiveAmount;
    private nullableInteger;
    private requiredDate;
    private nullableDate;
}
export {};
