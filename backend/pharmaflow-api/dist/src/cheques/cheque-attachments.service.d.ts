import { AuditLogService } from '../audit/audit-log.service';
import { PrismaService } from '../database/prisma/prisma.service';
import { ChequeAttachmentStorageService } from './cheque-attachment-storage.service';
import { ConfirmChequeAttachmentDto } from './dto/confirm-cheque-attachment.dto';
import { PrepareChequeAttachmentDto } from './dto/prepare-cheque-attachment.dto';
type AttachmentChangesQuery = {
    updatedAfter?: string;
    afterId?: string;
    limit?: string;
};
export declare class ChequeAttachmentsService {
    private readonly prisma;
    private readonly auditLog;
    private readonly storage;
    constructor(prisma: PrismaService, auditLog: AuditLogService, storage: ChequeAttachmentStorageService);
    prepareUpload(dto: PrepareChequeAttachmentDto): Promise<{
        attachmentId: string;
        storageKey: string;
        uploadUrl: string;
        expiresInSeconds: number;
    }>;
    confirmUpload(dto: ConfirmChequeAttachmentDto): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        sha256: string;
        storageKey: string;
        chequeId: string;
        kind: string;
        fileName: string;
        mimeType: string;
        originalFileSize: number | null;
        fileSize: number;
    }>;
    findAll(chequeId?: string): Promise<{
        id: string;
        createdAt: Date;
        updatedAt: Date;
        deletedAt: Date | null;
        sha256: string;
        storageKey: string;
        chequeId: string;
        kind: string;
        fileName: string;
        mimeType: string;
        originalFileSize: number | null;
        fileSize: number;
    }[]>;
    findChanges(query: AttachmentChangesQuery): Promise<{
        items: {
            id: string;
            createdAt: Date;
            updatedAt: Date;
            deletedAt: Date | null;
            sha256: string;
            storageKey: string;
            chequeId: string;
            kind: string;
            fileName: string;
            mimeType: string;
            originalFileSize: number | null;
            fileSize: number;
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
            chequeId: string;
            kind: string;
            fileName: string;
            mimeType: string;
            originalFileSize: number | null;
            fileSize: number;
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
        chequeId: string;
        kind: string;
        fileName: string;
        mimeType: string;
        originalFileSize: number | null;
        fileSize: number;
    }>;
    private requireActiveCheque;
    private parseChangesLimit;
}
export {};
