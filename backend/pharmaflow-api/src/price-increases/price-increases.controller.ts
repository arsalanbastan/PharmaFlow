import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  Patch,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { AuthGuard } from '../auth/auth.guard';
import { RolesGuard } from '../auth/roles.guard';
import { Roles } from '../auth/roles.decorator';
import { PermissionsGuard } from '../auth/permissions.guard';
import { Permissions } from '../auth/permissions.decorator';
import type { AuthenticatedRequest } from '../auth/auth-request';
import {
  CreatePriceIncreaseDto,
  CreatePriceIncreaseBatchDto,
  PriceNoticeTextDto,
  ConfirmPriceIncreaseDto,
  UpdatePriceIncreaseDto,
  CancelPriceIncreaseDto,
  PreparePriceAttachmentDto,
} from './price-increases.dto';
import { PriceImageService } from './price-image.service';
import { PriceIncreasesService } from './price-increases.service';

@Controller('api/v1/price-increases')
@UseGuards(AuthGuard, RolesGuard, PermissionsGuard)
@Roles('MANAGER', 'STAFF')
export class PriceIncreasesController {
  constructor(
    private readonly service: PriceIncreasesService,
    private readonly images: PriceImageService,
  ) {}

  @Post('extract-text')
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  extractText(@Body() dto: PriceNoticeTextDto) {
    return this.images.extractText(dto.text);
  }

  @Post('batch')
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  createBatch(@Body() dto: CreatePriceIncreaseBatchDto, @Req() req: AuthenticatedRequest) {
    return this.service.createBatch(dto.items, req.pharmaflowUser!, dto.requestKey);
  }
  @Get()
  list(
    @Query('q') q: string,
    @Query('status') status: string,
    @Query('category') category: string,
    @Query('from') from: string,
    @Query('to') to: string,
    @Query('page') page: string,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.service.list(
      { q, status, category, from, to, page },
      req.pharmaflowUser!,
    );
  }
  @Post()
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  create(
    @Body() dto: CreatePriceIncreaseDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.service.create(dto, req.pharmaflowUser!);
  }
  @Patch(':id')
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdatePriceIncreaseDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.service.update(id, dto, req.pharmaflowUser!);
  }

  @Post(':id/cancel')
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  cancel(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CancelPriceIncreaseDto,
    @Req() req: AuthenticatedRequest,
  ) {
    return this.service.cancel(id, dto, req.pharmaflowUser!);
  }

  @Post(':id/confirm')
  @Roles('STAFF')
  @Permissions('canCreateOrders')
  confirm(
    @Param('id', ParseUUIDPipe) id: string,
    @Req() req: AuthenticatedRequest,
    @Body() dto?: ConfirmPriceIncreaseDto,
  ) {
    return this.service.confirm(id, req.pharmaflowUser!, dto);
  }
  @Post(':id/attachments/prepare')
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  prepare(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PreparePriceAttachmentDto,
  ) {
    return this.service.prepare(id, dto);
  }
  @Post(':id/attachments/:attachmentId/confirm')
  @Roles('MANAGER')
  @Permissions('managerAppAccess')
  confirmAttachment(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('attachmentId', ParseUUIDPipe) attachmentId: string,
  ) {
    return this.service.confirmAttachment(id, attachmentId);
  }
  @Get(':id/attachments/:attachmentId')
  download(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('attachmentId', ParseUUIDPipe) attachmentId: string,
  ) {
    return this.service.download(id, attachmentId);
  }
}
