type PrepareUploadInput = {
    cashPaymentId: string;
    attachmentId: string;
    mimeType: string;
};
type VerifyUploadInput = PrepareUploadInput & {
    expectedFileSize: number;
};
export declare class CashPaymentAttachmentStorageService {
    createUploadUrl(input: PrepareUploadInput): Promise<{
        storageKey: string;
        uploadUrl: string;
        expiresInSeconds: number;
    }>;
    verifyUploadedObject(input: VerifyUploadInput): Promise<string>;
    createDownloadUrl(storageKey: string): Promise<{
        downloadUrl: string;
        expiresInSeconds: number;
    }>;
    buildStorageKey(input: PrepareUploadInput): string;
    private createClient;
    private extensionForMimeType;
    private assertSupportedMimeType;
    private requireText;
    private readPresignedTtlSeconds;
}
export {};
