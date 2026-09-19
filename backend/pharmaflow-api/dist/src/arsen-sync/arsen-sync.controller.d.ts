import { ArsenSyncService } from './arsen-sync.service';
import { ArsenCatalogItemBatchDto } from './dto/arsen-catalog-item-batch.dto';
import { ArsenCompanyBatchDto } from './dto/arsen-company-batch.dto';
import { ArsenInvoiceBatchDto } from './dto/arsen-invoice-batch.dto';
export declare class ArsenSyncController {
    private readonly arsenSyncService;
    constructor(arsenSyncService: ArsenSyncService);
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
    ingest(body: ArsenInvoiceBatchDto): Promise<{
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
    ingestCompanies(body: ArsenCompanyBatchDto): Promise<{
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
    ingestItems(body: ArsenCatalogItemBatchDto): Promise<{
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
}
