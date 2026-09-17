import { IsUUID } from 'class-validator';

import { PrepareCashPaymentAttachmentDto } from './prepare-cash-payment-attachment.dto';

export class ConfirmCashPaymentAttachmentDto extends PrepareCashPaymentAttachmentDto {
  @IsUUID()
  override id = '';
}
