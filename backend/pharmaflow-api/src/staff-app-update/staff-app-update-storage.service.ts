import {
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  GetObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const DEFAULT_TTL_SECONDS = 3600;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 86400;

@Injectable()
export class StaffAppUpdateStorageService {
  async createDownloadUrl(
    objectKey: string,
  ): Promise<string> {
    const endpoint =
      this.requireText('APP_UPDATE_S3_ENDPOINT');

    const bucket =
      this.requireText('APP_UPDATE_S3_BUCKET');

    const accessKeyId =
      this.requireText('APP_UPDATE_S3_ACCESS_KEY');

    const secretAccessKey =
      this.requireText('APP_UPDATE_S3_SECRET_KEY');

    const ttl =
      this.readTtl();

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
          expiresIn: ttl,
        },
      );
    } catch {
      throw new ServiceUnavailableException(
        'Unable to prepare Staff Android update URL.',
      );
    } finally {
      client.destroy();
    }
  }

  private requireText(name: string) {
    const value =
      process.env[name]?.trim();

    if (!value) {
      throw new ServiceUnavailableException(
        `Staff update storage configuration is invalid: ${name} is required.`,
      );
    }

    return value;
  }

  private readTtl() {
    const raw =
      process.env.APP_UPDATE_PRESIGNED_TTL_SECONDS?.trim();

    if (!raw) {
      return DEFAULT_TTL_SECONDS;
    }

    if (!/^\d+$/.test(raw)) {
      throw new ServiceUnavailableException(
        'APP_UPDATE_PRESIGNED_TTL_SECONDS must be an integer.',
      );
    }

    const value = Number(raw);

    return Math.min(
      Math.max(value, MIN_TTL_SECONDS),
      MAX_TTL_SECONDS,
    );
  }
}