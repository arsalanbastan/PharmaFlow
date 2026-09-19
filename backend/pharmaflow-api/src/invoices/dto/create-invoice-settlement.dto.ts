import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';

class InvoiceSettlementChequeDto {
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  amount: number;

  @IsUUID()
  bankAccountId: string;

  @IsString()
  @MaxLength(100)
  chequeNumber: string;

  @IsDateString()
  chequeDate: string;

  @IsOptional()
  @IsDateString()
  dueDate?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}

class InvoiceSettlementCashDto {
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  amount: number;

  @IsUUID()
  bankAccountId: string;

  @IsDateString()
  paymentDate: string;

  @IsIn(['BANK_DEPOSIT', 'POS_PAYMENT'])
  paymentMethod: string;

  @IsOptional()
  @IsString()
  @MaxLength(100)
  trackingNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string;
}

export class CreateInvoiceSettlementDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @IsUUID('4', { each: true })
  invoiceIds: string[];

  @IsOptional()
  @ValidateNested()
  @Type(() => InvoiceSettlementChequeDto)
  cheque?: InvoiceSettlementChequeDto;

  @IsOptional()
  @ValidateNested()
  @Type(() => InvoiceSettlementCashDto)
  cash?: InvoiceSettlementCashDto;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  discountAmount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  discountDescription?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  notes?: string;
}
