import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { ArsenCatalogItemDto } from './dto/arsen-catalog-item.dto';
import { ArsenCompanyDto } from './dto/arsen-company.dto';
import { ArsenInvoiceDto } from './dto/arsen-invoice.dto';
export declare class ArsenSyncService {
    private readonly prisma;
    private readonly auditLog;
    constructor(prisma: PrismaService, auditLog: AuditLogService);
    status(): Promise<{
        status: string;
        mappingCount: number;
        invoiceCount: number;
        latestInvoice: {
            sourceSyncedAt: Date;
            arsenFactorId: number;
            invoiceNumber: string | null;
            invoiceDate: string | null;
        } | null;
        itemCount: number;
        latestItem: {
            arsenDrugId: string;
            category: string;
            persianName: string | null;
            sourceSyncedAt: Date;
        } | null;
    }>;
    ingestCatalogItems(items: ArsenCatalogItemDto[]): Promise<{
        processed: number;
        created: number;
        updated: number;
        unchanged: number;
        results: {
            arsenDrugId: string;
            status: "UNCHANGED" | "UPDATED" | "CREATED";
            itemId: string;
        }[];
    }>;
    ingestCompanies(companies: ArsenCompanyDto[]): Promise<{
        processed: number;
        created: number;
        mapped: number;
        updated: number;
        unchanged: number;
        results: {
            arsenBusinessPartnerId: number;
            status: "CREATED" | "MAPPED" | "UPDATED" | "UNCHANGED";
            companyId: string;
        }[];
    }>;
    ingest(invoices: ArsenInvoiceDto[]): Promise<{
        processed: number;
        created: number;
        updated: number;
        unchanged: number;
        results: {
            arsenFactorId: number;
            status: "CREATED" | "UPDATED" | "UNCHANGED";
            invoiceId: string;
        }[];
    }>;
    private ingestOne;
}
