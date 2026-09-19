import { PrismaService } from '../database/prisma/prisma.service';
type CatalogFilters = {
    q?: string;
    category?: string;
    active?: string;
    page?: string;
    pageSize?: string;
};
export declare class CatalogService {
    private readonly prisma;
    constructor(prisma: PrismaService);
    findAll(filters?: CatalogFilters): Promise<{
        items: {
            id: string;
            arsenDrugId: string;
            category: string;
            persianName: string | null;
            genericName: string | null;
            persianBrandName: string | null;
            brandName: string | null;
            unit: string | null;
            shapeName: string | null;
            packetQuantity: number | null;
            salesPrice: string | null;
            lastPurchasePrice: string | null;
            isActive: boolean;
            sourceSyncedAt: string;
        }[];
        page: number;
        pageSize: number;
        totalCount: number;
        totalPages: number;
    }>;
    findOne(id: string): Promise<{
        id: string;
        arsenDrugId: string;
        category: string;
        persianName: string | null;
        genericName: string | null;
        persianBrandName: string | null;
        brandName: string | null;
        unit: string | null;
        shapeName: string | null;
        packetQuantity: number | null;
        salesPrice: string | null;
        lastPurchasePrice: string | null;
        isActive: boolean;
        description: string | null;
        importedAt: string;
        sourceSyncedAt: string;
    }>;
    private findWithoutSearch;
    private findWithSmartSearch;
    private serializeSummary;
    private buildBaseWhere;
    private parseSearchQuery;
    private buildTokenCondition;
    private searchVariants;
    private matchesAllTokens;
    private scoreRow;
    private normalizedSearchFields;
    private normalizeSearchText;
    private readPositiveInteger;
    private readPageSize;
    private decimalString;
}
export {};
