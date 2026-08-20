import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
} from '@nestjs/common';
import {
  GetObjectCommand,
  HeadObjectCommand,
  PutObjectCommand,
  S3Client,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const DEFAULT_PRESIGNED_TTL_SECONDS = 1800;
const MIN_PRESIGNED_TTL_SECONDS = 60;
const MAX_PRESIGNED_TTL_SECONDS = 86400;

const SUPPORTED_MIME_TYPES = new Map<string, string>([
  ['image/jpeg', 'jpg'],
  ['image/png', 'png'],
  ['image/webp', 'webp'],
  ['application/pdf', 'pdf'],
]);

type PrepareUploadInput = {
  chequeId: string;
  attachmentId: string;
  mimeType: string;
};

type VerifyUploadInput = PrepareUploadInput & {
  expectedFileSize: number;
};

@Injectable()
export class ChequeAttachmentStorageService {
  async createUploadUrl(input: PrepareUploadInput): Promise<{
    storageKey: string;
    uploadUrl: string;
    expiresInSeconds: number;
  }> {
    this.assertSupportedMimeType(input.mimeType);

    const storageKey = this.buildStorageKey(input);

    const expiresInSeconds = this.readPresignedTtlSeconds();

    const client = this.createClient();

    try {
      const uploadUrl = await getSignedUrl(
        client,
        new PutObjectCommand({
          Bucket: this.requireText('DOCUMENT_STORAGE_S3_BUCKET'),
          Key: storageKey,
          ContentType: input.mimeType,
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
        'Unable to prepare attachment upload URL.',
      );
    } finally {
      client.destroy();
    }
  }

  async verifyUploadedObject(input: VerifyUploadInput): Promise<string> {
    this.assertSupportedMimeType(input.mimeType);

    const storageKey = this.buildStorageKey(input);

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
        result.ContentLength !== input.expectedFileSize
      ) {
        throw new BadRequestException(
          'Uploaded attachment file size does not match the expected size.',
        );
      }

      const actualContentType = result.ContentType?.split(';')[0]
        .trim()
        .toLowerCase();

      if (
        actualContentType != null &&
        actualContentType.length > 0 &&
        actualContentType !== input.mimeType.toLowerCase()
      ) {
        throw new BadRequestException(
          'Uploaded attachment content type does not match the expected type.',
        );
      }

      return storageKey;
    } catch (error) {
      if (error instanceof BadRequestException) {
        throw error;
      }

      throw new BadRequestException(
        'Uploaded attachment could not be verified.',
      );
    } finally {
      client.destroy();
    }
  }

  async createDownloadUrl(storageKey: string): Promise<{
    downloadUrl: string;
    expiresInSeconds: number;
  }> {
    const expiresInSeconds = this.readPresignedTtlSeconds();

    const client = this.createClient();

    try {
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
        'Unable to prepare attachment download URL.',
      );
    } finally {
      client.destroy();
    }
  }

  buildStorageKey(input: PrepareUploadInput): string {
    const extension = this.extensionForMimeType(input.mimeType);

    return [
      'cheques',
      input.chequeId,
      `${input.attachmentId}.${extension}`,
    ].join('/');
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

  private extensionForMimeType(mimeType: string): string {
    const normalized = mimeType.trim().toLowerCase();

    const extension = SUPPORTED_MIME_TYPES.get(normalized);

    if (extension == null) {
      throw new BadRequestException('Unsupported attachment MIME type.');
    }

    return extension;
  }

  private assertSupportedMimeType(mimeType: string): void {
    this.extensionForMimeType(mimeType);
  }

  private requireText(name: string): string {
    const value = process.env[name]?.trim();

    if (!value) {
      throw new ServiceUnavailableException(
        `Document storage configuration is invalid: ${name} is required.`,
      );
    }

    return value;
  }

  private readPresignedTtlSeconds(): number {
    const raw = process.env.DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS?.trim();

    if (!raw) {
      return DEFAULT_PRESIGNED_TTL_SECONDS;
    }

    if (!/^\d+$/.test(raw)) {
      throw new ServiceUnavailableException(
        'DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS must be an integer.',
      );
    }

    const value = Number.parseInt(raw, 10);

    if (
      !Number.isSafeInteger(value) ||
      value < MIN_PRESIGNED_TTL_SECONDS ||
      value > MAX_PRESIGNED_TTL_SECONDS
    ) {
      throw new ServiceUnavailableException(
        'DOCUMENT_STORAGE_PRESIGNED_TTL_SECONDS must be between 60 and 86400.',
      );
    }

    return value;
  }
}
