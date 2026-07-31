import {
  IsOptional,
  IsString,
} from 'class-validator';

export class UpdateCompanyDto {
  @IsOptional()
  @IsString()
  name?: string;

  @IsOptional()
  @IsString()
  nationalId?: string;

  @IsOptional()
  @IsString()
  economicCode?: string;

  @IsOptional()
  @IsString()
  bankName?: string;

  @IsOptional()
  @IsString()
  accountNumber?: string;

  @IsOptional()
  @IsString()
  cardNumber?: string;

  @IsOptional()
  @IsString()
  shebaNumber?: string;

  @IsOptional()
  @IsString()
  notes?: string;

  @IsOptional()
  @IsString()
  visitorName?: string;

  @IsOptional()
  @IsString()
  visitorPhone?: string;

  @IsOptional()
  @IsString()
  accountantName?: string;

  @IsOptional()
  @IsString()
  accountantPhone?: string;
}