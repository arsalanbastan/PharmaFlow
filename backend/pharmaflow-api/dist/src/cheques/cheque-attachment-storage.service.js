"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChequeAttachmentStorageService = void 0;
const common_1 = require("@nestjs/common");
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const DEFAULT_PRESIGNED_TTL_SECONDS = 1800;
const MIN_PRESIGNED_TTL_SECONDS = 60;
const MAX_PRESIGNED_TTL_SECONDS = 86400;
const SUPPORTED_MIME_TYPES = new Map([
    ['image/jpeg', 'jpg'],
    ['image/png', 'png'],
    ['image/webp', 'webp'],
    ['application/pdf', 'pdf'],
]);
let ChequeAttachmentStorageService = class ChequeAttachmentStorageService {
    async createUploadUrl(input) {
        this.assertSupportedMimeType(input.mimeType);
        const storageKey = this.buildStorageKey(input);
        const expiresInSeconds = this.readPresignedTtlSeconds();
        const client = this.createClient();
        try {
            const uploadUrl = await (0, s3_request_presigner_1.getSignedUrl)(client, new client_s3_1.PutObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
                ContentType: input.mimeType,
            }), {
                expiresIn: expiresInSeconds,
            });
            return {
                storageKey,
                uploadUrl,
                expiresInSeconds,
            };
        }
        catch {
            throw new common_1.ServiceUnavailableException('Unable to prepare attachment upload URL.');
        }
        finally {
            client.destroy();
        }
    }
    async verifyUploadedObject(input) {
        this.assertSupportedMimeType(input.mimeType);
        const storageKey = this.buildStorageKey(input);
        const client = this.createClient();
        try {
            const result = await client.send(new client_s3_1.HeadObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
            }));
            if (result.ContentLength == null ||
                result.ContentLength !== input.expectedFileSize) {
                throw new common_1.BadRequestException('Uploaded attachment file size does not match the expected size.');
            }
            const actualContentType = result.ContentType?.split(';')[0]
                .trim()
                .toLowerCase();
            if (actualContentType != null &&
                actualContentType.length > 0 &&
                actualContentType !== input.mimeType.toLowerCase()) {
                throw new common_1.BadRequestException('Uploaded attachment content type does not match the expected type.');
            }
            return storageKey;
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException) {
                throw error;
            }
            throw new common_1.BadRequestException('Uploaded attachment could not be verified.');
        }
        finally {
            client.destroy();
        }
    }
    async createDownloadUrl(storageKey) {
        const expiresInSeconds = this.readPresignedTtlSeconds();
        const client = this.createClient();
        try {
            const downloadUrl = await (0, s3_request_presigner_1.getSignedUrl)(client, new client_s3_1.GetObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
            }), {
                expiresIn: expiresInSeconds,
            });
            return {
                downloadUrl,
                expiresInSeconds,
            };
        }
        catch {
            throw new common_1.ServiceUnavailableException('Unable to prepare attachment download URL.');
        }
        finally {
            client.destroy();
        }
    }
    buildStorageKey(input) {
        const extension = this.extensionForMimeType(input.mimeType);
        return [
            'cheques',
            input.chequeId,
            `${input.attachmentId}.${extension}`,
        ].join('/');
    }
    createClient() {
        const endpoint = this.requireText('DOCUMENT_STORAGE_S3_ENDPOINT');
        const accessKeyId = this.requireText('DOCUMENT_STORAGE_S3_ACCESS_KEY');
        const secretAccessKey = this.requireText('DOCUMENT_STORAGE_S3_SECRET_KEY');
        return new client_s3_1.S3Client({
            region: 'default',
            endpoint,
            credentials: {
                accessKeyId,
                secretAccessKey,
            },
            maxAttempts: 4,
        });
    }
    extensionForMimeType(mimeType) {
        const normalized = mimeType.trim().toLowerCase();
        const extension = SUPPORTED_MIME_TYPES.get(normalized);
        if (extension == null) {
            throw new common_1.BadRequestException('Unsupported attachment MIME type.');
        }
        return extension;
    }
    assertSupportedMimeType(mimeType) {
        this.extensionForMimeType(mimeType);
    }
    requireText(name) {
        const value = process.env[name]?.trim();
        if (!value) {
            throw new common_1.ServiceUnavailableException(`Document storage configuration is invalid: ${name} is required.`);
        }
        return value;
    }
    readPresignedTtlSeconds() {
        const raw = process.env.DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS?.trim();
        if (!raw) {
            return DEFAULT_PRESIGNED_TTL_SECONDS;
        }
        if (!/^\d+$/.test(raw)) {
            throw new common_1.ServiceUnavailableException('DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS must be an integer.');
        }
        const value = Number.parseInt(raw, 10);
        if (!Number.isSafeInteger(value) ||
            value < MIN_PRESIGNED_TTL_SECONDS ||
            value > MAX_PRESIGNED_TTL_SECONDS) {
            throw new common_1.ServiceUnavailableException('DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS must be between 60 and 86400.');
        }
        return value;
    }
};
exports.ChequeAttachmentStorageService = ChequeAttachmentStorageService;
exports.ChequeAttachmentStorageService = ChequeAttachmentStorageService = __decorate([
    (0, common_1.Injectable)()
], ChequeAttachmentStorageService);
//# sourceMappingURL=cheque-attachment-storage.service.js.map