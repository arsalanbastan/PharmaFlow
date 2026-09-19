import { ArsenInvoiceItemDto } from './arsen-invoice-item.dto';
export declare class ArsenInvoiceDto {
    arsenFactorId: number;
    invoiceNumber?: string | null;
    invoiceDate?: string | null;
    docDate?: string | null;
    settlementDate?: string | null;
    description?: string | null;
    factorDocType: number;
    factorDocTypeName?: string | null;
    factorType?: number | null;
    factorTypeName?: string | null;
    factorItemType?: string | null;
    arsenBusinessPartnerId: number;
    arsenBusinessPartnerName: string;
    factorTotalPrice?: string | null;
    factorDiscount?: string | null;
    factorTax?: string | null;
    factorPayablePrice?: string | null;
    barbariPrice?: string | null;
    paymentDays?: number | null;
    isDeletedInArsen: boolean;
    isLockedInArsen?: boolean | null;
    arsenSaveDateTime?: string | null;
    items: ArsenInvoiceItemDto[];
}
