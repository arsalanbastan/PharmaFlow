import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Permissions } from '../auth/permissions.decorator';
import { PermissionsGuard } from '../auth/permissions.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CashPaymentAttachmentsService } from './cash-payment-attachments.service';
import { ConfirmCashPaymentAttachmentDto } from './dto/confirm-cash-payment-attachment.dto';
import { PrepareCashPaymentAttachmentDto } from './dto/prepare-cash-payment-attachment.dto';

@Controller('api/v1/cash-payment-attachments')
export class CashPaymentAttachmentsController {
  constructor(
    private readonly attachmentsService: CashPaymentAttachmentsService,
  ) {}

  @Post('prepare-upload')
  @Permissions('canCreateCashPayments')
  @UseGuards(AuthGuard, PermissionsGuard)
  prepareUpload(
    @Body()
    dto: PrepareCashPaymentAttachmentDto,
  ) {
    return this.attachmentsService.prepareUpload(dto);
  }

  @Post('confirm')
  @Permissions('canCreateCashPayments')
  @UseGuards(AuthGuard, PermissionsGuard)
  confirmUpload(
    @Body()
    dto: ConfirmCashPaymentAttachmentDto,
  ) {
    return this.attachmentsService.confirmUpload(dto);
  }

  @Get()
  findAll(
    @Query('cashPaymentId')
    cashPaymentId?: string,
  ) {
    return this.attachmentsService.findAll(cashPaymentId);
  }

  @Get('changes')
  findChanges(
    @Query('updatedAfter')
    updatedAfter?: string,
    @Query('afterId')
    afterId?: string,
    @Query('limit')
    limit?: string,
  ) {
    return this.attachmentsService.findChanges({
      updatedAfter,
      afterId,
      limit,
    });
  }

  @Get(':id/download-url')
  createDownloadUrl(
    @Param('id')
    id: string,
  ) {
    return this.attachmentsService.createDownloadUrl(id);
  }

  @Delete(':id')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  remove(
    @Param('id')
    id: string,
  ) {
    return this.attachmentsService.remove(id);
  }
}
