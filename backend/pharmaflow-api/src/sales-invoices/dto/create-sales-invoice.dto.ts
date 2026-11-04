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

class CreateSalesInvoiceItemDto {
  @IsUUID()
  catalogItemId: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0.0001)
  quantity: number;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  unitPrice: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  lineDiscount?: number;
}


class CreateSalesInvoicePosPaymentDto {
  @IsString()
  @MaxLength(4096)
  receipt!: string;

  @IsString()
  @MaxLength(80)
  deviceId!: string;

  @IsString()
  @MaxLength(120)
  deviceName!: string;

  @IsString()
  @MaxLength(80)
  terminalId!: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  traceNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  rrn?: string;

  @IsString()
  @MaxLength(20)
  responseCode!: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  responseDescription?: string;

  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  paidAmount!: number;

  @IsDateString()
  paidAt!: string;
}

export class CreateSalesInvoiceDto {
  @IsDateString()
  issueDate: string;

  @IsOptional()
  @IsIn(['GOODS', 'OTC', 'FREE', 'MANUAL'])
  invoiceType?: 'GOODS' | 'OTC' | 'FREE' | 'MANUAL';

  @IsString()
  @MaxLength(250)
  @IsOptional()
  buyerName?: string;

  @IsOptional()
  @IsString()
  @MaxLength(20)
  buyerNationalId?: string;

  @IsOptional()
  @IsString()
  @MaxLength(50)
  buyerPhone?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  buyerAddress?: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @ValidateNested({ each: true })
  @Type(() => CreateSalesInvoiceItemDto)
  items: CreateSalesInvoiceItemDto[];

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 4 })
  @Min(0)
  discount?: number;

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  notes?: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => CreateSalesInvoicePosPaymentDto)
  posPayment?: CreateSalesInvoicePosPaymentDto;
}
