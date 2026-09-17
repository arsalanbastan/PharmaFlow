import { Equals, IsInt, Max, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class PrepareOrderPhotoDto {
  @Equals('image/jpeg')
  mimeType!: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(204800)
  fileSize!: number;
}
