import { ServiceUnavailableException } from '@nestjs/common';
import { AppUpdateService } from './app-update.service';
import type { AppUpdateStorageService } from './app-update-storage.service';

describe('AppUpdateService', () => {
  const originalEnvironment = { ...process.env };

  let storageService: {
    createAndroidDownloadUrl: jest.Mock;
  };

  let service: AppUpdateService;

  beforeEach(() => {
    process.env = { ...originalEnvironment };

    delete process.env.APP_UPDATE_ANDROID_ENABLED;
    delete process.env.APP_UPDATE_ANDROID_VERSION_NAME;
    delete process.env.APP_UPDATE_ANDROID_VERSION_CODE;
    delete process.env.APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE;
    delete process.env.APP_UPDATE_ANDROID_MANDATORY;
    delete process.env.APP_UPDATE_ANDROID_SHA256;
    delete process.env.APP_UPDATE_ANDROID_FILE_SIZE;
    delete process.env.APP_UPDATE_ANDROID_RELEASE_NOTES;
    delete process.env.APP_UPDATE_ANDROID_PUBLISHED_AT;

    storageService = {
      createAndroidDownloadUrl: jest
        .fn()
        .mockResolvedValue('https://signed.example.test/pharmaflow.apk'),
    };

    service = new AppUpdateService(
      storageService as unknown as AppUpdateStorageService,
    );
  });

  afterAll(() => {
    process.env = originalEnvironment;
  });

  it('returns a disabled manifest without touching storage', async () => {
    await expect(service.getAndroidManifest()).resolves.toEqual({
      enabled: false,
      platform: 'android',
    });

    expect(storageService.createAndroidDownloadUrl).not.toHaveBeenCalled();
  });

  it('returns an enabled manifest with a fresh signed URL', async () => {
    process.env.APP_UPDATE_ANDROID_ENABLED = 'true';
    process.env.APP_UPDATE_ANDROID_VERSION_NAME = '1.0.1';
    process.env.APP_UPDATE_ANDROID_VERSION_CODE = '2';
    process.env.APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE = '1';
    process.env.APP_UPDATE_ANDROID_MANDATORY = 'false';
    process.env.APP_UPDATE_ANDROID_SHA256 = 'a'.repeat(64);
    process.env.APP_UPDATE_ANDROID_FILE_SIZE = '73663491';
    process.env.APP_UPDATE_ANDROID_RELEASE_NOTES = 'Update downloader test';
    process.env.APP_UPDATE_ANDROID_PUBLISHED_AT = '2026-08-15T08:00:00.000Z';

    await expect(service.getAndroidManifest()).resolves.toEqual({
      enabled: true,
      platform: 'android',
      latestVersionName: '1.0.1',
      latestVersionCode: 2,
      minimumSupportedVersionCode: 1,
      mandatory: false,
      apkUrl: 'https://signed.example.test/pharmaflow.apk',
      sha256: 'a'.repeat(64),
      fileSize: 73663491,
      releaseNotes: 'Update downloader test',
      publishedAt: '2026-08-15T08:00:00.000Z',
    });

    expect(storageService.createAndroidDownloadUrl).toHaveBeenCalledTimes(1);
  });

  it('rejects an invalid SHA-256 before requesting storage', async () => {
    process.env.APP_UPDATE_ANDROID_ENABLED = 'true';
    process.env.APP_UPDATE_ANDROID_VERSION_NAME = '1.0.1';
    process.env.APP_UPDATE_ANDROID_VERSION_CODE = '2';
    process.env.APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE = '1';
    process.env.APP_UPDATE_ANDROID_SHA256 = 'bad';
    process.env.APP_UPDATE_ANDROID_FILE_SIZE = '73663491';

    await expect(service.getAndroidManifest()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );

    expect(storageService.createAndroidDownloadUrl).not.toHaveBeenCalled();
  });

  it('rejects minimum supported version above latest version', async () => {
    process.env.APP_UPDATE_ANDROID_ENABLED = 'true';
    process.env.APP_UPDATE_ANDROID_VERSION_NAME = '1.0.1';
    process.env.APP_UPDATE_ANDROID_VERSION_CODE = '2';
    process.env.APP_UPDATE_ANDROID_MIN_SUPPORTED_VERSION_CODE = '3';
    process.env.APP_UPDATE_ANDROID_SHA256 = 'b'.repeat(64);
    process.env.APP_UPDATE_ANDROID_FILE_SIZE = '73663491';

    await expect(service.getAndroidManifest()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );

    expect(storageService.createAndroidDownloadUrl).not.toHaveBeenCalled();
  });
});
