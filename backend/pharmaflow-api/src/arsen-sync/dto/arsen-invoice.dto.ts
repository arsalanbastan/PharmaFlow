import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Matches,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

import { ArsenInvoiceItemDto } from './arsen-invoice-item.dto';

const MONEY_TEXT = /^-?\d{1,16}(?:\.\d{1,4})?$/;

export class ArsenInvoiceDto {
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2147483647)
  arsenFactorId!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  invoiceNumber?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  invoiceDate?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  docDate?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  settlementDate?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string | null;

  @Type(() => Number)
  @IsIn([1, 2])
  factorDocType!: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  factorDocTypeName?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  factorType?: number | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  factorTypeName?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  factorItemType?: string | null;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(2147483647)
  arsenBusinessPartnerId!: number;

  @IsString()
  @MaxLength(500)
  arsenBusinessPartnerName!: string;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  factorTotalPrice?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  factorDiscount?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  factorTax?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  factorPayablePrice?: string | null;

  @IsOptional()
  @IsString()
  @Matches(MONEY_TEXT)
  barbariPrice?: string | null;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  @Max(36500)
  paymentDays?: number | null;

  @IsBoolean()
  isDeletedInArsen!: boolean;

  @IsOptional()
  @IsBoolean()
  isLockedInArsen?: boolean | null;

  @IsOptional()
  @IsDateString()
  arsenSaveDateTime?: string | null;

  @IsArray()
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => ArsenInvoiceItemDto)
  items!: ArsenInvoiceItemDto[];
}
