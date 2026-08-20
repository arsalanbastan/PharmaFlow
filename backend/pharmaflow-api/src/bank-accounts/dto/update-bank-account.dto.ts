import { IsDateString, IsOptional, IsString } from 'class-validator';

export class UpdateBankAccountDto {
  @IsOptional()
  @IsString()
  bankName?: string;

  @IsOptional()
  @IsString()
  accountTitle?: string | null;

  @IsOptional()
  @IsString()
  accountHolder?: string | null;

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
  @IsDateString()
  archivedAt?: string | null;
}
