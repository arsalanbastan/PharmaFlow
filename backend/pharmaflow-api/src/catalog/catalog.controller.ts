import {
  Controller,
  Get,
  Param,
  Query,
  UseGuards,
} from '@nestjs/common';

import { AuthGuard } from '../auth/auth.guard';
import { Roles } from '../auth/roles.decorator';
import { RolesGuard } from '../auth/roles.guard';
import { CatalogService } from './catalog.service';

@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/catalog')
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

  @Roles('MANAGER')
  @Get()
  findAll(
    @Query('q') q?: string,
    @Query('category') category?: string,
    @Query('active') active?: string,
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
  ) {
    return this.catalog.findAll({
      q,
      category,
      active,
      page,
      pageSize,
    });
  }

  @Roles('STAFF', 'MANAGER')
  @Get('staff-search')
  async staffSearch(@Query('q') q?: string, @Query('page') page?: string) {
    const result = await this.catalog.findAll({ q, active: 'ACTIVE', page, pageSize: '100' });
    return { ...result, items: result.items.map(({ id, category, persianName, genericName, persianBrandName, brandName, unit, shapeName, packetQuantity, salesPrice }) =>
      ({ id, category, persianName, genericName, persianBrandName, brandName, unit, shapeName, packetQuantity, salesPrice })) };
  }

  @Roles('MANAGER')
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.catalog.findOne(id);
  }
}
