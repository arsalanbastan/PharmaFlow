import {
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';

import { StaffAppUpdateStorageService } from './staff-app-update-storage.service';

@Injectable()
export class StaffAppUpdateService {
  constructor(
    private readonly storage:
      StaffAppUpdateStorageService,
  ) {}

  async getAndroidManifest() {
    const enabled =
      process.env.STAFF_APP_UPDATE_ANDROID_ENABLED
        ?.trim()
        .toLowerCase() === 'true';

    if (!enabled) {
      return {
        enabled: false,
        platform: 'android',
        app: 'staff',
      };
    }

    const latestVersionName =
      this.requireText(
        'STAFF_APP_UPDATE_ANDROID_VERSION_NAME',
      );

    const latestVersionCode =
      this.requirePositiveInt(
        'STAFF_APP_UPDATE_ANDROID_VERSION_CODE',
      );

    const minimumSupportedVersionCode =
      this.requirePositiveInt(
        'STAFF_APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE',
      );

    const mandatory =
      this.readBoolean(
        'STAFF_APP_UPDATE_ANDROID_MANDATORY',
      );

    const sha256 =
      this.requireText(
        'STAFF_APP_UPDATE_ANDROID_SHA256',
      ).toLowerCase();

    if (!/^[a-f0-9]{64}$/.test(sha256)) {
      throw new ServiceUnavailableException(
        'Staff update SHA256 is invalid.',
      );
    }

    const fileSize =
      this.requirePositiveInt(
        'STAFF_APP_UPDATE_ANDROID_FILE_SIZE',
      );

    const releaseNotes =
      process.env.STAFF_APP_UPDATE_ANDROID_RELEASE_NOTES
        ?.trim() || null;

    const objectKey =
      this.requireText(
        'STAFF_APP_UPDATE_S3_OBJECT_KEY',
      );

    const apkUrl =
      await this.storage.createDownloadUrl(
        objectKey,
      );

    return {
      enabled: true,
      platform: 'android',
      app: 'staff',
      latestVersionName,
      latestVersionCode,
      minimumSupportedVersionCode,
      mandatory,
      apkUrl,
      sha256,
      fileSize,
      releaseNotes,
      publishedAt: null,
    };
  }

  private requireText(name: string) {
    const value =
      process.env[name]?.trim();

    if (!value) {
      throw new ServiceUnavailableException(
        `Staff update configuration is invalid: ${name} is required.`,
      );
    }

    return value;
  }

  private requirePositiveInt(name: string) {
    const raw =
      this.requireText(name);

    if (!/^\d+$/.test(raw)) {
      throw new ServiceUnavailableException(
        `${name} must be a positive integer.`,
      );
    }

    const value = Number(raw);

    if (!Number.isSafeInteger(value) || value <= 0) {
      throw new ServiceUnavailableException(
        `${name} must be a positive integer.`,
      );
    }

    return value;
  }

  private readBoolean(name: string) {
    const raw =
      this.requireText(name).toLowerCase();

    if (raw === 'true') {
      return true;
    }

    if (raw === 'false') {
      return false;
    }

    throw new ServiceUnavailableException(
      `${name} must be true or false.`,
    );
  }
}