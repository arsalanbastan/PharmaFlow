import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CreateSalesInvoiceDto } from './dto/create-sales-invoice.dto';
import { UpdateSalesInvoiceProfileDto } from './dto/update-sales-invoice-profile.dto';
import { SalesInvoicesService } from './sales-invoices.service';

@Roles('MANAGER')
@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/sales-invoices')
export class SalesInvoicesController {
  constructor(private readonly salesInvoices: SalesInvoicesService) {}

  @Get()
  findAll(
    @Query('q') q?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.salesInvoices.findAll({ q, page, pageSize });
  }

  @Get('profile')
  profile() {
    return this.salesInvoices.profile();
  }

  @Put('profile')
  updateProfile(@Body() dto: UpdateSalesInvoiceProfileDto) {
    return this.salesInvoices.updateProfile(dto);
  }

  @Post()
  create(@Body() dto: CreateSalesInvoiceDto) {
    return this.salesInvoices.create(dto);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.salesInvoices.findOne(id);
  }
}
