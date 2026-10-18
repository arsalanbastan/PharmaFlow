import { IsNumber, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { Type } from 'class-transformer';

export class UpdateSalesInvoiceProfileDto {
  @IsString()
  @MaxLength(250)
  sellerName: string;

  @IsOptional()
  @IsString()
  @MaxLength(250)
  legalName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  nationalId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(30)
  economicCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  phone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  address?: string;

  @IsOptional()
  @IsString()
  @MaxLength(2000000)
  logoData?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  manualServiceTariff?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  freeServiceTariff?: number;
}
