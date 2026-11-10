import {
  IsIn,
  IsInt,
  IsNumberString,
  IsOptional,
  IsString,
  Length,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
export class CreatePriceIncreaseDto {
  @IsString() @Length(1, 300) productName!: string;
  @IsIn(['DRUG', 'GOODS']) category!: string;
  // Prices use the same rial unit as catalog and sales invoices.
  @IsNumberString({ no_symbols: false }) newPrice!: string;
  @IsString() @Length(10, 10) effectiveDate!: string;
  @IsString() @Length(1, 500) source!: string;
  @IsOptional() @IsString() @MaxLength(3000) notes?: string;
}
export class UpdatePriceIncreaseDto extends CreatePriceIncreaseDto {}

export class CancelPriceIncreaseDto {
  @IsString() @Length(1, 1000) reason!: string;
}

export class PreparePriceAttachmentDto {
  @IsString() @Length(1, 200) fileName!: string;
  @IsIn(['image/jpeg', 'image/png', 'image/webp', 'application/pdf'])
  mimeType!: string;
  @IsInt() @Min(1) @Max(10 * 1024 * 1024) fileSize!: number;
}
