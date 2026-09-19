"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StaffAppUpdateStorageService = void 0;
const common_1 = require("@nestjs/common");
const client_s3_1 = require("@aws-sdk/client-s3");
const s3_request_presigner_1 = require("@aws-sdk/s3-request-presigner");
const DEFAULT_TTL_SECONDS = 3600;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 86400;
let StaffAppUpdateStorageService = class StaffAppUpdateStorageService {
    async createDownloadUrl(objectKey) {
        const endpoint = this.requireText('APP_UPDATE_S3_ENDPOINT');
        const bucket = this.requireText('APP_UPDATE_S3_BUCKET');
        const accessKeyId = this.requireText('APP_UPDATE_S3_ACCESS_KEY');
        const secretAccessKey = this.requireText('APP_UPDATE_S3_SECRET_KEY');
        const ttl = this.readTtl();
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
                expiresIn: ttl,
            });
        }
        catch {
            throw new common_1.ServiceUnavailableException('Unable to prepare Staff Android update URL.');
        }
        finally {
            client.destroy();
        }
    }
    requireText(name) {
        const value = process.env[name]?.trim();
        if (!value) {
            throw new common_1.ServiceUnavailableException(`Staff update storage configuration is invalid: ${name} is required.`);
        }
        return value;
    }
    readTtl() {
        const raw = process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS?.trim();
        if (!raw) {
            return DEFAULT_TTL_SECONDS;
        }
        if (!/^\d+$/.test(raw)) {
            throw new common_1.ServiceUnavailableException('APP_UPDATE_PRESIGNED_TTL_SECONDS must be an integer.');
        }
        const value = Number(raw);
        return Math.min(Math.max(value, MIN_TTL_SECONDS), MAX_TTL_SECONDS);
    }
};
exports.StaffAppUpdateStorageService = StaffAppUpdateStorageService;
exports.StaffAppUpdateStorageService = StaffAppUpdateStorageService = __decorate([
    (0, common_1.Injectable)()
], StaffAppUpdateStorageService);
//# sourceMappingURL=staff-app-update-storage.service.js.map