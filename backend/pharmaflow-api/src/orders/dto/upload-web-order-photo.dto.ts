import {
  Equals,
  IsBase64,
  IsInt,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

const MAX_JPEG_BASE64_LENGTH = 273068;

export class UploadWebOrderPhotoDto {
  @Equals('image/jpeg')
  mimeType!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(204800)
  fileSize!: number;

  @Matches(/^[a-fA-F0-9]{64}$/)
  sha256!: string;

  @IsBase64()
  @MaxLength(MAX_JPEG_BASE64_LENGTH)
  imageBase64!: string;
}
