import {
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { UpdateInvoicePaymentStatusDto } from './dto/update-invoice-payment-status.dto';
import { InvoicesService } from './invoices.service';

@Roles('MANAGER')
@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/invoices')
export class InvoicesController {
  constructor(private readonly invoices: InvoicesService) {}

  @Get()
  findAll(
    @Query('q') q?: string,
    @Query('companyId') companyId?: string,
    @Query('dateFrom') dateFrom?: string,
    @Query('dateTo') dateTo?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.invoices.findAll({
      q,
      companyId,
      dateFrom,
      dateTo,
      page,
      pageSize,
    });
  }

  @Patch(':id/payment-status')
  updatePaymentStatus(
    @Param('id') id: string,
    @Body() dto: UpdateInvoicePaymentStatusDto,
  ) {
    return this.invoices.updatePaymentStatus(id, dto.isPaid);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.invoices.findOne(id);
  }
}