import {
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateBankAccountDto {
  @IsString()
  bankName: string;

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
}
