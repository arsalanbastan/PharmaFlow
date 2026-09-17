import { ServiceUnavailableException } from '@nestjs/common';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { AppUpdateStorageService } from './app-update-storage.service';

jest.mock('@aws-sdk/s3-request-presigner', () => ({
  getSignedUrl: jest.fn(),
}));

describe('AppUpdateStorageService', () => {
  const originalEnvironment = { ...process.env };

  const getSignedUrlMock = getSignedUrl as jest.MockedFunction<
    typeof getSignedUrl
  >;

  beforeEach(() => {
    process.env = { ...originalEnvironment };

    process.env.APP_UPDATE_S3_ENDPOINT = 'https://storage.example.test';

    process.env.APP_UPDATE_S3_BUCKET = 'test-bucket';

    process.env.APP_UPDATE_S3_OBJECT_KEY = 'releases/pharmaflow-1.0.1+2.apk';

    process.env.APP_UPDATE_S3_ACCESS_KEY = 'test-access-key';

    process.env.APP_UPDATE_S3_SECRET_KEY = 'test-secret-key';

    delete process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS;

    getSignedUrlMock.mockReset();

    getSignedUrlMock.mockResolvedValue('https://signed.example.test/download');
  });

  afterAll(() => {
    process.env = originalEnvironment;
  });

  it('creates a signed URL with 3600 second default TTL', async () => {
    const service = new AppUpdateStorageService();

    await expect(service.createAndroidDownloadUrl()).resolves.toBe(
      'https://signed.example.test/download',
    );

    expect(getSignedUrlMock).toHaveBeenCalledTimes(1);

    expect(getSignedUrlMock.mock.calls[0][2]).toEqual(
      expect.objectContaining({
        expiresIn: 3600,
      }),
    );
  });

  it('accepts a configured TTL', async () => {
    process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS = '7200';

    const service = new AppUpdateStorageService();

    await service.createAndroidDownloadUrl();

    expect(getSignedUrlMock.mock.calls[0][2]).toEqual(
      expect.objectContaining({
        expiresIn: 7200,
      }),
    );
  });

  it('rejects missing storage credentials', async () => {
    delete process.env.APP_UPDATE_S3_SECRET_KEY;

    const service = new AppUpdateStorageService();

    await expect(service.createAndroidDownloadUrl()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('rejects invalid TTL', async () => {
    process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS = '10';

    const service = new AppUpdateStorageService();

    await expect(service.createAndroidDownloadUrl()).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});
