import { CatalogService } from './catalog.service';
export declare class CatalogController {
    private readonly catalog;
    constructor(catalog: CatalogService);
    findAll(q?: string, category?: string, active?: string, page?: string, pageSize?: string): Promise<{
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
    staffSearch(q?: string, page?: string): Promise<{
        items: {
            id: string;
            category: string;
            persianName: string | null;
            genericName: string | null;
            persianBrandName: string | null;
            brandName: string | null;
            unit: string | null;
            shapeName: string | null;
            packetQuantity: number | null;
            salesPrice: string | null;
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
}
