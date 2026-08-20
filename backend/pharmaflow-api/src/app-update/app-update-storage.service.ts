import { Injectable, ServiceUnavailableException } from '@nestjs/common';
import { GetObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const DEFAULT_PRESIGNED_TTL_SECONDS = 3600;
const MIN_PRESIGNED_TTL_SECONDS = 60;
const MAX_PRESIGNED_TTL_SECONDS = 86400;

@Injectable()
export class AppUpdateStorageService {
  async createAndroidDownloadUrl(): Promise<string> {
    const endpoint = this.requireText('APP_UPDATE_S3_ENDPOINT');

    const bucket = this.requireText('APP_UPDATE_S3_BUCKET');

    const objectKey = this.requireText('APP_UPDATE_S3_OBJECT_KEY');

    const accessKeyId = this.requireText('APP_UPDATE_S3_ACCESS_KEY');

    const secretAccessKey = this.requireText('APP_UPDATE_S3_SECRET_KEY');

    const expiresIn = this.readPresignedTtlSeconds();

    const client = new S3Client({
      region: 'default',
      endpoint,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
      maxAttempts: 4,
    });

    try {
      return await getSignedUrl(
        client,
        new GetObjectCommand({
          Bucket: bucket,
          Key: objectKey,
        }),
        {
          expiresIn,
        },
      );
    } catch {
      throw new ServiceUnavailableException(
        'Unable to prepare Android app update download URL.',
      );
    } finally {
      client.destroy();
    }
  }

  private requireText(name: string): string {
    const value = process.env[name]?.trim();

    if (!value) {
      throw new ServiceUnavailableException(
        `Android app update storage configuration is invalid: ${name} is required.`,
      );
    }

    return value;
  }

  private readPresignedTtlSeconds(): number {
    const raw = process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS?.trim();

    if (!raw) {
      return DEFAULT_PRESIGNED_TTL_SECONDS;
    }

    if (!/^\d+$/.test(raw)) {
      throw new ServiceUnavailableException(
        'Android app update storage configuration is invalid: APP_UPDATE_PRESIGNED_TTL_SECONDS must be an integer.',
      );
    }

    const value = Number.parseInt(raw, 10);

    if (
      !Number.isSafeInteger(value) ||
      value < MIN_PRESIGNED_TTL_SECONDS ||
      value > MAX_PRESIGNED_TTL_SECONDS
    ) {
      throw new ServiceUnavailableException(
        'Android app update storage configuration is invalid: APP_UPDATE_PRESIGNED_TTL_SECONDS must be between 60 and 86400.',
      );
    }

    return value;
  }
}
