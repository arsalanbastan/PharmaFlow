import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsDateString,
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

export class CreateSalesInvoiceDto {
  @IsDateString()
  issueDate: string;

  @IsString()
  @MaxLength(250)
  buyerName: string;

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
}
