import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  DeleteObjectCommand,
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const MAX_ORDER_PHOTO_BYTES = 200 * 1024;
const DEFAULT_TTL_SECONDS = 1800;
const MIN_TTL_SECONDS = 60;
const MAX_TTL_SECONDS = 86400;

type PhotoObjectInput = {
  orderId: string;
  mimeType: string;
  fileSize: number;
};

@Injectable()
export class OrderPhotoStorageService {
  async createUploadUrl(input: PhotoObjectInput) {
    this.assertInput(input);

    const storageKey = this.buildStorageKey(input.orderId);

    const expiresInSeconds = this.readPresignedTtlSeconds();

    const client = this.createClient();

    try {
      const uploadUrl = await getSignedUrl(
        client,
        new PutObjectCommand({
          Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
          Key: storageKey,
          ContentType: 'image/jpeg',
        }),
        {
          expiresIn: expiresInSeconds,
        },
      );

      return {
        storageKey,
        uploadUrl,
        expiresInSeconds,
      };
    } catch {
      throw new ServiceUnavailableException(
        'Unable to prepare order photo upload URL.',
      );
    } finally {
      client.destroy();
    }
  }

  async uploadBytes(input: PhotoObjectInput, bytes: Buffer): Promise<string> {
    this.assertInput(input);

    if (bytes.length !== input.fileSize) {
      throw new BadRequestException(
        'Order photo byte length does not match the declared file size.',
      );
    }

    const storageKey = this.buildStorageKey(input.orderId);
    const client = this.createClient();

    try {
      await client.send(
        new PutObjectCommand({
          Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
          Key: storageKey,
          Body: bytes,
          ContentLength: bytes.length,
          ContentType: 'image/jpeg',
        }),
      );

      return storageKey;
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new ServiceUnavailableException(
        'Unable to upload order photo through the web gateway.',
      );
    } finally {
      client.destroy();
    }
  }

  async verifyUploadedObject(input: PhotoObjectInput): Promise<string> {
    this.assertInput(input);

    const storageKey = this.buildStorageKey(input.orderId);

    const client = this.createClient();

    try {
      const result = await client.send(
        new HeadObjectCommand({
          Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
          Key: storageKey,
        }),
      );

      if (
        result.ContentLength == null ||
        result.ContentLength !== input.fileSize
      ) {
        throw new BadRequestException(
          'Uploaded order photo size does not match expected size.',
        );
      }

      if (
        result.ContentLength <= 0 ||
        result.ContentLength > MAX_ORDER_PHOTO_BYTES
      ) {
        throw new BadRequestException('Order photo exceeds the 200KB limit.');
      }

      const contentType = result.ContentType?.split(';')[0]
        .trim()
        .toLowerCase();

      if (
        contentType != null &&
        contentType.length > 0 &&
        contentType !== 'image/jpeg'
      ) {
        throw new BadRequestException('Uploaded order photo must be JPEG.');
      }

      return storageKey;
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new ServiceUnavailableException(
        'Unable to verify uploaded order photo.',
      );
    } finally {
      client.destroy();
    }
  }

  async createDownloadUrl(storageKey: string) {
    const client = this.createClient();

    try {
      const expiresInSeconds = this.readPresignedTtlSeconds();

      const downloadUrl = await getSignedUrl(
        client,
        new GetObjectCommand({
          Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
          Key: storageKey,
        }),
        {
          expiresIn: expiresInSeconds,
        },
      );

      return {
        downloadUrl,
        expiresInSeconds,
      };
    } catch {
      throw new ServiceUnavailableException(
        'Unable to prepare order photo download URL.',
      );
    } finally {
      client.destroy();
    }
  }

  async deleteObject(storageKey: string): Promise<void> {
    const client = this.createClient();

    try {
      await client.send(
        new DeleteObjectCommand({
          Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
          Key: storageKey,
        }),
      );
    } catch {
      throw new ServiceUnavailableException(
        'Unable to delete order photo from storage.',
      );
    } finally {
      client.destroy();
    }
  }

  buildStorageKey(orderId: string): string {
    return `order-requests/${orderId}/request.jpg`;
  }

  private assertInput(input: PhotoObjectInput) {
    if (input.mimeType.trim().toLowerCase() !== 'image/jpeg') {
      throw new BadRequestException('Order photo must be JPEG.');
    }

    if (
      !Number.isInteger(input.fileSize) ||
      input.fileSize <= 0 ||
      input.fileSize > MAX_ORDER_PHOTO_BYTES
    ) {
      throw new BadRequestException(
        'Order photo must be between 1 byte and 200KB.',
      );
    }
  }

  private createClient(): S3Client {
    const endpoint = this.requireText('DOCUMENT_STORAGE_S3_ENDPOINT');

    const accessKeyId = this.requireText('DOCUMENT_STORAGE_S3_ACCESS_KEY');

    const secretAccessKey = this.requireText('DOCUMENT_STORAGE_S3_SECRET_KEY');

    return new S3Client({
      region: 'default',
      endpoint,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
      maxAttempts: 4,
    });
  }

  private requireText(name: string): string {
    const value = process.env[name]?.trim();

    if (!value) {
      throw new ServiceUnavailableException(
        `Order photo storage configuration is invalid: ${name} is required.`,
      );
    }

    return value;
  }

  private readPresignedTtlSeconds() {
    const raw = process.env.DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS?.trim();

    if (!raw) {
      return DEFAULT_TTL_SECONDS;
    }

    if (!/^\d+$/.test(raw)) {
      throw new ServiceUnavailableException(
        'DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS must be an integer.',
      );
    }

    const value = Number(raw);

    if (value < MIN_TTL_SECONDS || value > MAX_TTL_SECONDS) {
      throw new ServiceUnavailableException(
        'DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS is out of range.',
      );
    }

    return value;
  }
}
