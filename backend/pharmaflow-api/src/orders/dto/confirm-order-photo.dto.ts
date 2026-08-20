import { Equals, IsInt, Matches, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class ConfirmOrderPhotoDto {
  @Equals('image/jpeg')
  mimeType!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(204800)
  fileSize!: number;

  @Matches(/^[a-fA-F0-9]{64}$/)
  sha256!: string;
}
