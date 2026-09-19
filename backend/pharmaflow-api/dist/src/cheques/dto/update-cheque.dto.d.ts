export declare class UpdateChequeDto {
    chequeNumber?: string;
    amount?: number;
    chequeDate?: string;
    dueDate?: string | null;
    companyId?: string;
    bankAccountId?: string;
    sayadStatus?: string | null;
    status?: string | null;
    isRegisteredInSayad?: boolean;
    sayadId?: string | null;
    imagePath?: string;
    imageData?: string;
    description?: string | null;
    archivedAt?: string | null;
}
