"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppUpdateStorageService = void 0;
const common_1 = require("@nestjs/common");
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const DEFAULT_PRESIGNED_TTL_SECONDS = 3600;
const MIN_PRESIGNED_TTL_SECONDS = 60;
const MAX_PRESIGNED_TTL_SECONDS = 86400;
let AppUpdateStorageService = class AppUpdateStorageService {
    async createAndroidDownloadUrl() {
        const endpoint = this.requireText('APP_UPDATE_S3_ENDPOINT');
        const bucket = this.requireText('APP_UPDATE_S3_BUCKET');
        const objectKey = this.requireText('APP_UPDATE_S3_OBJECT_KEY');
        const accessKeyId = this.requireText('APP_UPDATE_S3_ACCESS_KEY');
        const secretAccessKey = this.requireText('APP_UPDATE_S3_SECRET_KEY');
        const expiresIn = this.readPresignedTtlSeconds();
        const client = new client_s3_1.S3Client({
            region: 'default',
            endpoint,
            credentials: {
                accessKeyId,
                secretAccessKey,
            },
            maxAttempts: 4,
        });
        try {
            return await (0, s3_request_presigner_1.getSignedUrl)(client, new client_s3_1.GetObjectCommand({
                Bucket: bucket,
                Key: objectKey,
            }), {
                expiresIn,
            });
        }
        catch {
            throw new common_1.ServiceUnavailableException('Unable to prepare Android app update download URL.');
        }
        finally {
            client.destroy();
        }
    }
    requireText(name) {
        const value = process.env[name]?.trim();
        if (!value) {
            throw new common_1.ServiceUnavailableException(`Android app update storage configuration is invalid: ${name} is required.`);
        }
        return value;
    }
    readPresignedTtlSeconds() {
        const raw = process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS?.trim();
        if (!raw) {
            return DEFAULT_PRESIGNED_TTL_SECONDS;
        }
        if (!/^\d+$/.test(raw)) {
            throw new common_1.ServiceUnavailableException('Android app update storage configuration is invalid: APP_UPDATE_PRESIGNED_TTL_SECONDS must be an integer.');
        }
        const value = Number.parseInt(raw, 10);
        if (!Number.isSafeInteger(value) ||
            value < MIN_PRESIGNED_TTL_SECONDS ||
            value > MAX_PRESIGNED_TTL_SECONDS) {
            throw new common_1.ServiceUnavailableException('Android app update storage configuration is invalid: APP_UPDATE_PRESIGNED_TTL_SECONDS must be between 60 and 86400.');
        }
        return value;
    }
};
exports.AppUpdateStorageService = AppUpdateStorageService;
exports.AppUpdateStorageService = AppUpdateStorageService = __decorate([
    (0, common_1.Injectable)()
], AppUpdateStorageService);
//# sourceMappingURL=app-update-storage.service.js.map