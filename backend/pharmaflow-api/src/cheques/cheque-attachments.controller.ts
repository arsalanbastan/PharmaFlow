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
import { ChequeAttachmentsService } from './cheque-attachments.service';
import { ConfirmChequeAttachmentDto } from './dto/confirm-cheque-attachment.dto';
import { PrepareChequeAttachmentDto } from './dto/prepare-cheque-attachment.dto';

@Controller('api/v1/cheque-attachments')
export class ChequeAttachmentsController {
  constructor(private readonly attachmentsService: ChequeAttachmentsService) {}

  @Post('prepare-upload')
  @Permissions('canCreateCheques')
  @UseGuards(AuthGuard, PermissionsGuard)
  prepareUpload(
    @Body()
    dto: PrepareChequeAttachmentDto,
  ) {
    return this.attachmentsService.prepareUpload(dto);
  }

  @Post('confirm')
  @Permissions('canCreateCheques')
  @UseGuards(AuthGuard, PermissionsGuard)
  confirmUpload(
    @Body()
    dto: ConfirmChequeAttachmentDto,
  ) {
    return this.attachmentsService.confirmUpload(dto);
  }

  @Get()
  findAll(
    @Query('chequeId')
    chequeId?: string,
  ) {
    return this.attachmentsService.findAll(chequeId);
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
