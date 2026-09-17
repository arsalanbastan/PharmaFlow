import {
  IsBoolean,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

import { Type } from 'class-transformer';

export class UpdateChequeDto {
  @IsOptional()
  @IsString()
  chequeNumber?: string;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  amount?: number;

  @IsOptional()
  @IsDateString()
  chequeDate?: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string | null;

  @IsOptional()
  @IsUUID()
  companyId?: string;

  @IsOptional()
  @IsUUID()
  bankAccountId?: string;

  @IsOptional()
  @IsString()
  sayadStatus?: string | null;

  @IsOptional()
  @IsString()
  status?: string | null;

  @IsOptional()
  @IsBoolean()
  isRegisteredInSayad?: boolean;

  @IsOptional()
  @IsString()
  sayadId?: string | null;

  @IsOptional()
  @IsString()
  imagePath?: string;

  @IsOptional()
  @IsString()
  imageData?: string;

  @IsOptional()
  @IsString()
  description?: string | null;

  @IsOptional()
  @IsDateString()
  archivedAt?: string | null;
}
