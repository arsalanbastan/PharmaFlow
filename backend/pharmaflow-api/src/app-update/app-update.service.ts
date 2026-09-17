import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { AppUpdateStorageService } from './app-update-storage.service';

export interface AndroidUpdateManifestDisabled {
  enabled: false;
  platform: 'android';
}

export interface AndroidUpdateManifestEnabled {
  enabled: true;
  platform: 'android';
  latestVersionName: string;
  latestVersionCode: number;
  minimumSupportedVersionCode: number;
  mandatory: boolean;
  apkUrl: string;
  sha256: string;
  fileSize: number;
  releaseNotes: string;
  publishedAt: string | null;
}

export type AndroidUpdateManifest =
  AndroidUpdateManifestDisabled | AndroidUpdateManifestEnabled;

const SHA256_PATTERN = /^[a-fA-F0-9]{64}$/;

@Injectable()
export class AppUpdateService {
  constructor(private readonly storageService: AppUpdateStorageService) {}

  async getAndroidManifest(): Promise<AndroidUpdateManifest> {
    if (!this.readBoolean('APP_UPDATE_ANDROID_ENABLED', false)) {
      return {
        enabled: false,
        platform: 'android',
      };
    }

    const latestVersionName = this.requireText(
      'APP_UPDATE_ANDROID_VERSION_NAME',
    );

    const latestVersionCode = this.requirePositiveInteger(
      'APP_UPDATE_ANDROID_VERSION_CODE',
    );

    const minimumSupportedVersionCode = this.requirePositiveInteger(
      'APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE',
    );

    if (minimumSupportedVersionCode > latestVersionCode) {
      throw this.configurationError(
        'APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE cannot exceed APP_UPDATE_ANDROID_VERSION_CODE.',
      );
    }

    const sha256 = this.requireText('APP_UPDATE_ANDROID_SHA256').toLowerCase();

    if (!SHA256_PATTERN.test(sha256)) {
      throw this.configurationError(
        'APP_UPDATE_ANDROID_SHA256 must contain exactly 64 hexadecimal characters.',
      );
    }

    const fileSize = this.requirePositiveInteger(
      'APP_UPDATE_ANDROID_FILE_SIZE',
    );

    const releaseNotes =
      process.env.APP_UPDATE_ANDROID_RELEASE_NOTES?.trim() ?? '';

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

  private requireText(name: string): string {
    const value = process.env[name]?.trim();

    if (!value) {
      throw this.configurationError(`${name} is required.`);
    }

    return value;
  }

  private requirePositiveInteger(name: string): number {
    const raw = this.requireText(name);
    const value = Number.parseInt(raw, 10);

    if (!/^\d+$/.test(raw) || !Number.isSafeInteger(value) || value <= 0) {
      throw this.configurationError(`${name} must be a positive integer.`);
    }

    return value;
  }

  private readBoolean(name: string, fallback: boolean): boolean {
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

  private readPublishedAt(): string | null {
    const raw = process.env.APP_UPDATE_ANDROID_PUBLISHED_AT?.trim();

    if (!raw) {
      return null;
    }

    const parsed = new Date(raw);

    if (Number.isNaN(parsed.getTime())) {
      throw this.configurationError(
        'APP_UPDATE_ANDROID_PUBLISHED_AT must be a valid date/time.',
      );
    }

    return parsed.toISOString();
  }

  private configurationError(message: string): ServiceUnavailableException {
    return new ServiceUnavailableException(
      `Android app update configuration is invalid: ${message}`,
    );
  }
}
