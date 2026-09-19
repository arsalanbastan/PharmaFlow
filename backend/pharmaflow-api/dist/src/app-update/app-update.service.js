"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppUpdateService = void 0;
const common_1 = require("@nestjs/common");
const app_update_storage_service_1 = require("./app-update-storage.service");
const SHA256_PATTERN = /^[a-fA-F0-9]{64}$/;
let AppUpdateService = class AppUpdateService {
    storageService;
    constructor(storageService) {
        this.storageService = storageService;
    }
    async getAndroidManifest() {
        if (!this.readBoolean('APP_UPDATE_ANDROID_ENABLED', false)) {
            return {
                enabled: false,
                platform: 'android',
            };
        }
        const latestVersionName = this.requireText('APP_UPDATE_ANDROID_VERSION_NAME');
        const latestVersionCode = this.requirePositiveInteger('APP_UPDATE_ANDROID_VERSION_CODE');
        const minimumSupportedVersionCode = this.requirePositiveInteger('APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE');
        if (minimumSupportedVersionCode > latestVersionCode) {
            throw this.configurationError('APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE cannot exceed APP_UPDATE_ANDROID_VERSION_CODE.');
        }
        const sha256 = this.requireText('APP_UPDATE_ANDROID_SHA256').toLowerCase();
        if (!SHA256_PATTERN.test(sha256)) {
            throw this.configurationError('APP_UPDATE_ANDROID_SHA256 must contain exactly 64 hexadecimal characters.');
        }
        const fileSize = this.requirePositiveInteger('APP_UPDATE_ANDROID_FILE_SIZE');
        const releaseNotes = process.env.APP_UPDATE_ANDROID_RELEASE_NOTES?.trim() ?? '';
        const publishedAt = this.readPublishedAt();
        const apkUrl = await this.storageService.createAndroidDownloadUrl();
        return {
            enabled: true,
            platform: 'android',
            latestVersionName,
            latestVersionCode,
            minimumSupportedVersionCode,
            mandatory: this.readBoolean('APP_UPDATE_ANDROID_MANDATORY', false),
            apkUrl,
            sha256,
            fileSize,
            releaseNotes,
            publishedAt,
        };
    }
    requireText(name) {
        const value = process.env[name]?.trim();
        if (!value) {
            throw this.configurationError(`${name} is required.`);
        }
        return value;
    }
    requirePositiveInteger(name) {
        const raw = this.requireText(name);
        const value = Number.parseInt(raw, 10);
        if (!/^\d+$/.test(raw) || !Number.isSafeInteger(value) || value <= 0) {
            throw this.configurationError(`${name} must be a positive integer.`);
        }
        return value;
    }
    readBoolean(name, fallback) {
        const raw = process.env[name]?.trim().toLowerCase();
        if (!raw) {
            return fallback;
        }
        if (raw === 'true') {
            return true;
        }
        if (raw === 'false') {
            return false;
        }
        throw this.configurationError(`${name} must be true or false.`);
    }
    readPublishedAt() {
        const raw = process.env.APP_UPDATE_ANDROID_PUBLISHED_AT?.trim();
        if (!raw) {
            return null;
        }
        const parsed = new Date(raw);
        if (Number.isNaN(parsed.getTime())) {
            throw this.configurationError('APP_UPDATE_ANDROID_PUBLISHED_AT must be a valid date/time.');
        }
        return parsed.toISOString();
    }
    configurationError(message) {
        return new common_1.ServiceUnavailableException(`Android app update configuration is invalid: ${message}`);
    }
};
exports.AppUpdateService = AppUpdateService;
exports.AppUpdateService = AppUpdateService = __decorate([
    (0, common_1.Injectable)(),
    __metadata("design:paramtypes", [app_update_storage_service_1.AppUpdateStorageService])
], AppUpdateService);
//# sourceMappingURL=app-update.service.js.map