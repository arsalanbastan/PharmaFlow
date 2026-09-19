type PhotoObjectInput = {
    orderId: string;
    mimeType: string;
    fileSize: number;
};
export declare class OrderPhotoStorageService {
    createUploadUrl(input: PhotoObjectInput): Promise<{
        storageKey: string;
        uploadUrl: string;
        expiresInSeconds: number;
    }>;
    uploadBytes(input: PhotoObjectInput, bytes: Buffer): Promise<string>;
    verifyUploadedObject(input: PhotoObjectInput): Promise<string>;
    createDownloadUrl(storageKey: string): Promise<{
        downloadUrl: string;
        expiresInSeconds: number;
    }>;
    deleteObject(storageKey: string): Promise<void>;
    buildStorageKey(orderId: string): string;
    private assertInput;
    private createClient;
    private requireText;
    private readPresignedTtlSeconds;
}
export {};
