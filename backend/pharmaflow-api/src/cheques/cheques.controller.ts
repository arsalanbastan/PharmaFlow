import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';

import { ChequesService } from './cheques.service';
import { CreateChequeDto } from './dto/create-cheque.dto';
import { UpdateChequeDto } from './dto/update-cheque.dto';

@Controller('api/v1/cheques')
export class ChequesController {
  constructor(
    private readonly chequesService: ChequesService,
  ) {}

  @Post()
  create(
    @Body() createChequeDto: CreateChequeDto,
  ) {
    return this.chequesService.create(createChequeDto);
  }

  @Get()
  findAll() {
    return this.chequesService.findAll();
  }

  @Get(':id')
  findOne(
    @Param('id') id: string,
  ) {
    return this.chequesService.findOne(id);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() updateChequeDto: UpdateChequeDto,
  ) {
    return this.chequesService.update(id, updateChequeDto);
  }

  @Delete(':id')
  remove(
    @Param('id') id: string,
  ) {
    return this.chequesService.remove(id);
  }
}
