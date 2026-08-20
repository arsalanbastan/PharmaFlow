import {
  IsDateString,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

export class CreateCompanyDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  nationalId?: string | null;

  @IsOptional()
  @IsString()
  economicCode?: string | null;

  @IsOptional()
  @IsString()
  bankName?: string | null;

  @IsOptional()
  @IsString()
  accountNumber?: string | null;

  @IsOptional()
  @IsString()
  cardNumber?: string | null;

  @IsOptional()
  @IsString()
  shebaNumber?: string | null;

  @IsOptional()
  @IsString()
  notes?: string | null;

  @IsOptional()
  @IsString()
  visitorName?: string | null;

  @IsOptional()
  @IsString()
  visitorPhone?: string | null;

  @IsOptional()
  @IsString()
  accountantName?: string | null;

  @IsOptional()
  @IsString()
  accountantPhone?: string | null;

  @IsOptional()
  @IsDateString()
  archivedAt?: string | null;
}