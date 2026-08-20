import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
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
import { ChequesService } from './cheques.service';
import { CreateChequeDto } from './dto/create-cheque.dto';
import { UpdateChequeDto } from './dto/update-cheque.dto';

@Controller('api/v1/cheques')
export class ChequesController {
  constructor(private readonly chequesService: ChequesService) {}

  @Post()
  @Permissions('canCreateCheques')
  @UseGuards(AuthGuard, PermissionsGuard)
  create(@Body() createChequeDto: CreateChequeDto) {
    return this.chequesService.create(createChequeDto);
  }

  @Get()
  findAll() {
    return this.chequesService.findAll();
  }

  @Get('changes')
  findChanges(
    @Query('updatedAfter') updatedAfter?: string,
    @Query('afterId') afterId?: string,
    @Query('limit') limit?: string,
  ) {
    return this.chequesService.findChanges({
      updatedAfter,
      afterId,
      limit,
    });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.chequesService.findOne(id);
  }

  @Patch(':id')
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  update(@Param('id') id: string, @Body() updateChequeDto: UpdateChequeDto) {
    return this.chequesService.update(id, updateChequeDto);
  }

  @Delete(':uuid')
  @HttpCode(HttpStatus.NO_CONTENT)
  @Roles('MANAGER')
  @UseGuards(AuthGuard, RolesGuard)
  remove(@Param('uuid') uuid: string) {
    return this.chequesService.remove(uuid);
  }
}
