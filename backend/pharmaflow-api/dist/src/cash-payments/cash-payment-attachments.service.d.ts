import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { CashPaymentAttachmentStorageService } from './cash-payment-attachment-storage.service';
import { ConfirmCashPaymentAttachmentDto } from './dto/confirm-cash-payment-attachment.dto';
import { PrepareCashPaymentAttachmentDto } from './dto/prepare-cash-payment-attachment.dto';
type AttachmentChangesQuery = {
    updatedAfter?: string;
    afterId?: string;
    limit?: string;
};
export declare class CashPaymentAttachmentsService {
    private readonly prisma;
    private readonly auditLog;
    private readonly storage;
    constructor(prisma: PrismaService, auditLog: AuditLogService, storage: CashPaymentAttachmentStorageService);
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
    findChanges(query: AttachmentChangesQuery): Promise<{
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
    private requireActiveCashPayment;
    private parseChangesLimit;
}
export {};
