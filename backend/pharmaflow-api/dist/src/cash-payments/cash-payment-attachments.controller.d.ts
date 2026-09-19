import { CashPaymentAttachmentsService } from './cash-payment-attachments.service';
import { ConfirmCashPaymentAttachmentDto } from './dto/confirm-cash-payment-attachment.dto';
import { PrepareCashPaymentAttachmentDto } from './dto/prepare-cash-payment-attachment.dto';
export declare class CashPaymentAttachmentsController {
    private readonly attachmentsService;
    constructor(attachmentsService: CashPaymentAttachmentsService);
    prepareUpload(dto: PrepareCashPaymentAttachmentDto): Promise<{
        attachmentId: string;
        storageKey: string;
        uploadUrl: string;
        expiresInSeconds: number;
    }>;
    confirmUpload(dto: ConfirmCashPaymentAttachmentDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        sha256: string;
        storageKey: string;
        kind: string;
        fileName: string;
        mimeType: string;
        originalFileSize: number | null;
        fileSize: number;
        cashPaymentId: string;
    }>;
    findAll(cashPaymentId?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        sha256: string;
        storageKey: string;
        kind: string;
        fileName: string;
        mimeType: string;
        originalFileSize: number | null;
        fileSize: number;
        cashPaymentId: string;
    }[]>;
    findChanges(updatedAfter?: string, afterId?: string, limit?: string): Promise<{
        items: {
            id: string;
            createdAt: Date;
            updatedAt: Date;
            deletedAt: Date | null;
            sha256: string;
            storageKey: string;
            kind: string;
            fileName: string;
            mimeType: string;
            originalFileSize: number | null;
            fileSize: number;
            cashPaymentId: string;
        }[];
        hasMore: boolean;
        nextCursor: {
            updatedAt: string;
            id: string;
        } | null;
    }>;
    createDownloadUrl(id: string): Promise<{
        attachment: {
            id: string;
            createdAt: Date;
            updatedAt: Date;
            deletedAt: Date | null;
            sha256: string;
            storageKey: string;
            kind: string;
            fileName: string;
            mimeType: string;
            originalFileSize: number | null;
            fileSize: number;
            cashPaymentId: string;
        };
        downloadUrl: string;
        expiresInSeconds: number;
    }>;
    remove(id: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        sha256: string;
        storageKey: string;
        kind: string;
        fileName: string;
        mimeType: string;
        originalFileSize: number | null;
        fileSize: number;
        cashPaymentId: string;
    }>;
}
