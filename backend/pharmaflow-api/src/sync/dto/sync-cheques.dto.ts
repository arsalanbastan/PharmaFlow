import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  ValidateNested,
} from 'class-validator';

export class SyncChequeDto {
  @IsString()
  chequeNumber: string;

  @Type(() => Number)
  @IsNumber()
  amount: number;

  @IsDateString()
  chequeDate: string;

  @IsUUID()
  companyId: string;

  @IsUUID()
  bankAccountId: string;

  @IsOptional()
  @IsString()
  description?: string;
}

export class SyncChequesDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => SyncChequeDto)
  cheques: SyncChequeDto[];
}