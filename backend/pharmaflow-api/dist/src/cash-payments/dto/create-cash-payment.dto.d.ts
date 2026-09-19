export declare class CreateCashPaymentDto {
    id?: string;
    amount: number;
    paymentDate: string;
    companyId: string;
    bankAccountId: string;
    paymentMethod: string;
    trackingNumber?: string | null;
    description?: string | null;
    notes?: string | null;
    archivedAt?: string | null;
}
