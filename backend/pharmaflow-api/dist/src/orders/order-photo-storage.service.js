"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrderPhotoStorageService = void 0;
const common_1 = require("@nestjs/common");
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const MAX_ORDER_PHOTO_BYTES = 200 * 1024;
const DEFAULT_TTL_SECONDS = 1800;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 86400;
let OrderPhotoStorageService = class OrderPhotoStorageService {
    async createUploadUrl(input) {
        this.assertInput(input);
        const storageKey = this.buildStorageKey(input.orderId);
        const expiresInSeconds = this.readPresignedTtlSeconds();
        const client = this.createClient();
        try {
            const uploadUrl = await (0, s3_request_presigner_1.getSignedUrl)(client, new client_s3_1.PutObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
                ContentType: 'image/jpeg',
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
            throw new common_1.ServiceUnavailableException('Unable to prepare order photo upload URL.');
        }
        finally {
            client.destroy();
        }
    }
    async uploadBytes(input, bytes) {
        this.assertInput(input);
        if (bytes.length !== input.fileSize) {
            throw new common_1.BadRequestException('Order photo byte length does not match the declared file size.');
        }
        const storageKey = this.buildStorageKey(input.orderId);
        const client = this.createClient();
        try {
            await client.send(new client_s3_1.PutObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
                Body: bytes,
                ContentLength: bytes.length,
                ContentType: 'image/jpeg',
            }));
            return storageKey;
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException) {
                throw error;
            }
            throw new common_1.ServiceUnavailableException('Unable to upload order photo through the web gateway.');
        }
        finally {
            client.destroy();
        }
    }
    async verifyUploadedObject(input) {
        this.assertInput(input);
        const storageKey = this.buildStorageKey(input.orderId);
        const client = this.createClient();
        try {
            const result = await client.send(new client_s3_1.HeadObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
            }));
            if (result.ContentLength == null ||
                result.ContentLength !== input.fileSize) {
                throw new common_1.BadRequestException('Uploaded order photo size does not match expected size.');
            }
            if (result.ContentLength <= 0 ||
                result.ContentLength > MAX_ORDER_PHOTO_BYTES) {
                throw new common_1.BadRequestException('Order photo exceeds the 200KB limit.');
            }
            const contentType = result.ContentType?.split(';')[0]
                .trim()
                .toLowerCase();
            if (contentType != null &&
                contentType.length > 0 &&
                contentType !== 'image/jpeg') {
                throw new common_1.BadRequestException('Uploaded order photo must be JPEG.');
            }
            return storageKey;
        }
        catch (error) {
            if (error instanceof common_1.BadRequestException) {
                throw error;
            }
            throw new common_1.ServiceUnavailableException('Unable to verify uploaded order photo.');
        }
        finally {
            client.destroy();
        }
    }
    async createDownloadUrl(storageKey) {
        const client = this.createClient();
        try {
            const expiresInSeconds = this.readPresignedTtlSeconds();
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
            throw new common_1.ServiceUnavailableException('Unable to prepare order photo download URL.');
        }
        finally {
            client.destroy();
        }
    }
    async deleteObject(storageKey) {
        const client = this.createClient();
        try {
            await client.send(new client_s3_1.DeleteObjectCommand({
                Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
                Key: storageKey,
            }));
        }
        catch {
            throw new common_1.ServiceUnavailableException('Unable to delete order photo from storage.');
        }
        finally {
            client.destroy();
        }
    }
    buildStorageKey(orderId) {
        return `order-requests/${orderId}/request.jpg`;
    }
    assertInput(input) {
        if (input.mimeType.trim().toLowerCase() !== 'image/jpeg') {
            throw new common_1.BadRequestException('Order photo must be JPEG.');
        }
        if (!Number.isInteger(input.fileSize) ||
            input.fileSize <= 0 ||
            input.fileSize > MAX_ORDER_PHOTO_BYTES) {
            throw new common_1.BadRequestException('Order photo must be between 1 byte and 200KB.');
        }
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
    requireText(name) {
        const value = process.env[name]?.trim();
        if (!value) {
            throw new common_1.ServiceUnavailableException(`Order photo storage configuration is invalid: ${name} is required.`);
        }
        return value;
    }
    readPresignedTtlSeconds() {
        const raw = process.env.DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS?.trim();
        if (!raw) {
            return DEFAULT_TTL_SECONDS;
        }
        if (!/^\d+$/.test(raw)) {
            throw new common_1.ServiceUnavailableException('DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS must be an integer.');
        }
        const value = Number(raw);
        if (value < MIN_TTL_SECONDS || value > MAX_TTL_SECONDS) {
            throw new common_1.ServiceUnavailableException('DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS is out of range.');
        }
        return value;
    }
};
exports.OrderPhotoStorageService = OrderPhotoStorageService;
exports.OrderPhotoStorageService = OrderPhotoStorageService = __decorate([
    (0, common_1.Injectable)()
], OrderPhotoStorageService);
//# sourceMappingURL=order-photo-storage.service.js.map