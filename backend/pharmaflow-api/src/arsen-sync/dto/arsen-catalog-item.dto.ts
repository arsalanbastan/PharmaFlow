import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const BIGINT_TEXT = /^\d{1,20}$/;
const MONEY_TEXT = /^-?\d{1,16}(?:\.\d{1,4})?$/;

export class ArsenCatalogItemDto {
  @IsString()
  @Matches(BIGINT_TEXT)
  arsenDrugId!: string;

  @IsBoolean()
  isDrug!: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  persianName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  genericName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  persianBrandName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  brandName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  unit?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  shapeName?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(-2147483648)
  @Max(2147483647)
  packetQuantity?: number | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  salesPrice?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  lastPurchasePrice?: string | null;

  @IsBoolean()
  isActive!: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string | null;
}
