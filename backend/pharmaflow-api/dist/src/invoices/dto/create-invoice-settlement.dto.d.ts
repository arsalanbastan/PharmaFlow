declare class InvoiceSettlementChequeDto {
    amount: number;
    bankAccountId: string;
    chequeNumber: string;
    chequeDate: string;
    dueDate?: string;
    description?: string;
}
declare class InvoiceSettlementCashDto {
    amount: number;
    bankAccountId: string;
    paymentDate: string;
    paymentMethod: string;
    trackingNumber?: string;
    description?: string;
}
export declare class CreateInvoiceSettlementDto {
    invoiceIds: string[];
    cheque?: InvoiceSettlementChequeDto;
    cash?: InvoiceSettlementCashDto;
    discountAmount?: number;
    discountDescription?: string;
    notes?: string;
}
export {};
