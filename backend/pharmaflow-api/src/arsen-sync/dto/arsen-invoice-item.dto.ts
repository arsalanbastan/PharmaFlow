import { Type } from 'class-transformer';
import {
  IsDateString,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

const BIGINT_TEXT = /^\d{1,20}$/;
const MONEY_TEXT = /^-?\d{1,16}(?:\.\d{1,4})?$/;

export class ArsenInvoiceItemDto {
  @IsString()
  @Matches(BIGINT_TEXT)
  arsenFactorDetailId!: string;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(2147483647)
  arsenFactorDetailsId?: number | null;

  @IsOptional()
  @IsString()
  @Matches(BIGINT_TEXT)
  arsenDrugId?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  drugName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  barcode?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(-2147483648)
  @Max(2147483647)
  packetQuantity?: number | null;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ allowInfinity: false, allowNaN: false })
  quantity?: number | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  salePrice?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  purchasePrice?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  rowDiscount?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  // Arsen's legacy column name is HasMaliat, but for purchase invoice
  // details it stores the row TAX AMOUNT (integer Rials), not a boolean flag
  // and not a percentage.
  @Max(2147483647)
  hasTax?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  expireDate?: string | null;

  @IsOptional()
  @IsDateString()
  expireDateGregorian?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  batchNumber?: string | null;
}
