import { Type } from 'class-transformer';
import {
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';

import { CASH_PAYMENT_METHODS } from '../cash-payment.constants';

export class CreateCashPaymentDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  @Type(() => Number)
  @IsInt()
  @Min(1)
  amount: number;

  @IsDateString()
  paymentDate: string;

  @IsUUID()
  companyId: string;

  @IsUUID()
  bankAccountId: string;

  @IsIn(CASH_PAYMENT_METHODS)
  paymentMethod: string;

  @IsOptional()
  @IsString()
  trackingNumber?: string | null;

  @IsOptional()
  @IsString()
  description?: string | null;

  @IsOptional()
  @IsString()
  notes?: string | null;

  @IsOptional()
  @IsDateString()
  archivedAt?: string | null;
}