import { Type } from 'class-transformer';
import {
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const BIGINT_TEXT = /^\d{1,20}$/;

export class ArsenCatalogBarcodeDto {
  @IsString()
  @Matches(BIGINT_TEXT)
  arsenBarcodeId!: string;

  @IsString()
  @MaxLength(200)
  barcode!: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  barcodeNormalized?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(-2147483648)
  @Max(2147483647)
  defQnt?: number | null;
}
