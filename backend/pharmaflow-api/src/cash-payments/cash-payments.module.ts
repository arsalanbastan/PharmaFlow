import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { CashPaymentAttachmentsController } from './cash-payment-attachments.controller';
import { CashPaymentAttachmentStorageService } from './cash-payment-attachment-storage.service';
import { CashPaymentAttachmentsService } from './cash-payment-attachments.service';
import { CashPaymentsController } from './cash-payments.controller';
import { CashPaymentsService } from './cash-payments.service';

@Module({
  imports: [AuthModule],
  controllers: [CashPaymentsController, CashPaymentAttachmentsController],
  providers: [
    CashPaymentsService,
    CashPaymentAttachmentsService,
    CashPaymentAttachmentStorageService,
  ],
  exports: [CashPaymentsService, CashPaymentAttachmentsService],
})
export class CashPaymentsModule {}
