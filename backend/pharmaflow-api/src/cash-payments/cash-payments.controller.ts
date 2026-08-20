import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Permissions } from '../auth/permissions.decorator';
import { PermissionsGuard } from '../auth/permissions.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CashPaymentsService } from './cash-payments.service';
import { CreateCashPaymentDto } from './dto/create-cash-payment.dto';
import { UpdateCashPaymentDto } from './dto/update-cash-payment.dto';

@Controller('api/v1/cash-payments')
export class CashPaymentsController {
  constructor(private readonly cashPaymentsService: CashPaymentsService) {}

  @Post()
  @Permissions('canCreateCashPayments')
  @UseGuards(AuthGuard, PermissionsGuard)
  create(@Body() createCashPaymentDto: CreateCashPaymentDto) {
    return this.cashPaymentsService.create(createCashPaymentDto);
  }

  @Get()
  findAll() {
    return this.cashPaymentsService.findAll();
  }

  @Get('changes')
  findChanges(
    @Query('updatedAfter') updatedAfter?: string,
    @Query('afterId') afterId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.cashPaymentsService.findChanges({
      updatedAfter,
      afterId,
      limit,
    });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.cashPaymentsService.findOne(id);
  }

  @Patch(':id')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  update(
    @Param('id') id: string,
    @Body() updateCashPaymentDto: UpdateCashPaymentDto,
  ) {
    return this.cashPaymentsService.update(id, updateCashPaymentDto);
  }

  @Delete(':id')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  remove(@Param('id') id: string) {
    return this.cashPaymentsService.remove(id);
  }
}
