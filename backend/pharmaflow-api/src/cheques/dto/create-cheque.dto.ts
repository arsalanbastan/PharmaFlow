import {
  IsBoolean,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
} from 'class-validator';

import { Type } from 'class-transformer';

export class CreateChequeDto {
  @IsString()
  chequeNumber: string;

  @Type(() => Number)
  @IsNumber()
  amount: number;

  @IsDateString()
  chequeDate: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsUUID()
  companyId: string;

  @IsUUID()
  bankAccountId: string;

  @IsOptional()
  @IsString()
  sayadStatus?: string;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsBoolean()
  isRegisteredInSayad?: boolean;

  @IsOptional()
  @IsString()
  sayadId?: string;

  @IsOptional()
  @IsString()
  imagePath?: string;

  @IsOptional()
  @IsString()
  imageData?: string;

  @IsOptional()
  @IsString()
  description?: string;
}
