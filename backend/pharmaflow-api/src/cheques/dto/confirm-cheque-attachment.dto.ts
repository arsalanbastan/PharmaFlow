import { IsUUID } from 'class-validator';

import { PrepareChequeAttachmentDto } from './prepare-cheque-attachment.dto';

export class ConfirmChequeAttachmentDto extends PrepareChequeAttachmentDto {
  @IsUUID()
  override id = '';
}
