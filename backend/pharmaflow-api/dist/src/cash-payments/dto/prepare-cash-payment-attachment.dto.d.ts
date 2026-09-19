export declare const MAX_CASH_PAYMENT_ATTACHMENT_BYTES: number;
export declare class PrepareCashPaymentAttachmentDto {
    id?: string;
    cashPaymentId: string;
    kind: string;
    fileName: string;
    mimeType: string;
    originalFileSize?: number;
    fileSize: number;
    sha256: string;
}
