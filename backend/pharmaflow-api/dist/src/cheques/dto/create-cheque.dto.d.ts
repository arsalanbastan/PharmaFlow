export declare class CreateChequeDto {
    id?: string;
    chequeNumber: string;
    amount: number;
    chequeDate: string;
    dueDate?: string;
    companyId: string;
    bankAccountId: string;
    sayadStatus?: string;
    status?: string;
    isRegisteredInSayad?: boolean;
    sayadId?: string;
    imagePath?: string;
    imageData?: string;
    description?: string;
    archivedAt?: string;
}
