export declare const MAX_CHEQUE_ATTACHMENT_BYTES: number;
export declare class PrepareChequeAttachmentDto {
    id?: string;
    chequeId: string;
    kind: string;
    fileName: string;
    mimeType: string;
    originalFileSize?: number;
    fileSize: number;
    sha256: string;
}
