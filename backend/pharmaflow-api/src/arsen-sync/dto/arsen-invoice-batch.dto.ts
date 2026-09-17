import { Type } from 'class-transformer';
import { ArrayMaxSize, ArrayMinSize, IsArray, ValidateNested } from 'class-validator';

import { ArsenInvoiceDto } from './arsen-invoice.dto';

export class ArsenInvoiceBatchDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(25)
  @ValidateNested({ each: true })
  @Type(() => ArsenInvoiceDto)
  invoices!: ArsenInvoiceDto[];
}
