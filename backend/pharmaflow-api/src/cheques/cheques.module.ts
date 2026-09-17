import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { ChequeAttachmentStorageService } from './cheque-attachment-storage.service';
import { ChequeAttachmentsController } from './cheque-attachments.controller';
import { ChequeAttachmentsService } from './cheque-attachments.service';
import { ChequesController } from './cheques.controller';
import { ChequesService } from './cheques.service';

@Module({
  imports: [AuthModule],
  controllers: [ChequesController, ChequeAttachmentsController],
  providers: [
    ChequesService,
    ChequeAttachmentsService,
    ChequeAttachmentStorageService,
  ],
  exports: [ChequesService, ChequeAttachmentsService],
})
export class ChequesModule {}
