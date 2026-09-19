declare class CreateSalesInvoiceItemDto {
    catalogItemId: string;
    quantity: number;
    unitPrice: number;
    lineDiscount?: number;
}
export declare class CreateSalesInvoiceDto {
    issueDate: string;
    buyerName: string;
    buyerNationalId?: string;
    buyerPhone?: string;
    buyerAddress?: string;
    items: CreateSalesInvoiceItemDto[];
    discount?: number;
    notes?: string;
}
export {};
