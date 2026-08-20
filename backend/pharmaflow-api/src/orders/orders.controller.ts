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
import { AssignOrderRequestDto } from './dto/assign-order-request.dto';
import { CheckOrderDuplicateDto } from './dto/check-order-duplicate.dto';
import { ConfirmOrderPhotoDto } from './dto/confirm-order-photo.dto';
import { CreateOrderRequestDto } from './dto/create-order-request.dto';
import { PrepareOrderPhotoDto } from './dto/prepare-order-photo.dto';
import { UpdateOrderCategoryDto } from './dto/update-order-category.dto';
import { UpdatePendingOrderRequestDto } from './dto/update-pending-order-request.dto';
import { UploadWebOrderPhotoDto } from './dto/upload-web-order-photo.dto';
import { OrdersAvailabilityGuard } from './orders-availability.guard';
import { OrdersService } from './orders.service';

@UseGuards(OrdersAvailabilityGuard, AuthGuard, RolesGuard, PermissionsGuard)
@Controller('api/v1/orders')
export class OrdersController {
  constructor(private readonly ordersService: OrdersService) {}

  @Post('duplicate-check')
  @Permissions('canCreateOrders')
  checkDuplicate(@Body() dto: CheckOrderDuplicateDto) {
    return this.ordersService.checkDuplicate(dto);
  }

  @Post()
  @Permissions('canCreateOrders')
  create(@Body() dto: CreateOrderRequestDto) {
    return this.ordersService.create(dto);
  }

  @Get()
  findAll(
    @Query('status') status?: string,
    @Query('category') category?: string,
  ) {
    return this.ordersService.findAll({
      status,
      category,
    });
  }

  @Get('changes')
  findChanges(
    @Query('updatedAfter') updatedAfter?: string,
    @Query('afterId') afterId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.ordersService.findChanges({
      updatedAfter,
      afterId,
      limit,
    });
  }

  @Post(':id/photo/prepare')
  @Permissions('canCreateOrders')
  preparePhotoUpload(
    @Param('id') id: string,
    @Body() dto: PrepareOrderPhotoDto,
  ) {
    return this.ordersService.preparePhotoUpload(id, dto);
  }

  @Post(':id/photo/confirm')
  @Permissions('canCreateOrders')
  confirmPhotoUpload(
    @Param('id') id: string,
    @Body() dto: ConfirmOrderPhotoDto,
  ) {
    return this.ordersService.confirmPhotoUpload(id, dto);
  }

  @Post(':id/photo/upload-web')
  @Permissions('canCreateOrders')
  uploadWebPhoto(@Param('id') id: string, @Body() dto: UploadWebOrderPhotoDto) {
    return this.ordersService.uploadWebPhoto(id, dto);
  }

  @Get(':id/photo')
  getPhoto(@Param('id') id: string) {
    return this.ordersService.createPhotoDownload(id);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.ordersService.findOne(id);
  }

  @Post(':id/category')
  @Permissions('canCreateOrders')
  updateCategory(@Param('id') id: string, @Body() dto: UpdateOrderCategoryDto) {
    return this.ordersService.updateCategory(id, dto);
  }

  @Post(':id/edit')
  @Roles('STAFF', 'MANAGER')
  @Permissions('canCreateOrders')
  updatePending(
    @Param('id') id: string,
    @Body() dto: UpdatePendingOrderRequestDto,
  ) {
    return this.ordersService.updatePending(id, dto);
  }
  @Post(':id/assign')
  @Roles('MANAGER')
  assign(@Param('id') id: string, @Body() dto: AssignOrderRequestDto) {
    return this.ordersService.assign(id, dto);
  }

  @Post(':id/return-to-pending')
  @Roles('MANAGER')
  returnToPending(@Param('id') id: string) {
    return this.ordersService.returnToPending(id);
  }

  @Post(':id/receive')
  @Permissions('canCreateOrders')
  receive(@Param('id') id: string) {
    return this.ordersService.receive(id);
  }

  @Post(':id/cancel')
  @Roles('MANAGER')
  cancel(@Param('id') id: string) {
    return this.ordersService.cancel(id);
  }

  @Delete(':id')
  @Roles('STAFF', 'MANAGER')
  @Permissions('canCreateOrders')
  removePending(@Param('id') id: string) {
    return this.ordersService.removePending(id);
  }
}
