import { IsBoolean } from 'class-validator';

export class UpdateInvoicePaymentStatusDto {
  @IsBoolean()
  isPaid!: boolean;
}