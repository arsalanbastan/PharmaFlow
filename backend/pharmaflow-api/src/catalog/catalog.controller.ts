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

@Roles('MANAGER')
@UseGuards(AuthGuard, RolesGuard)
@Controller('api/v1/catalog')
export class CatalogController {
  constructor(private readonly catalog: CatalogService) {}

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

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.catalog.findOne(id);
  }
}