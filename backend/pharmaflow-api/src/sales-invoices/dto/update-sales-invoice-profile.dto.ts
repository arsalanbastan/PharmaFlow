import { IsOptional, IsString, MaxLength } from 'class-validator';

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
}
