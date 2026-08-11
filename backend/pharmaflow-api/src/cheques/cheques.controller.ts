import {
  Body,
  Controller,
  Delete,
  Get,
  HttpException,
  Param,
  Patch,
  Post,
  Req,
  Res,
} from '@nestjs/common';
import type { Request, Response } from 'express';

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
    @Req() request: Request,
    @Res({ passthrough: true }) response: Response,
  ) {
    console.log(
      JSON.stringify({
        requestReceived: 'yes',
        responseStatus: null,
        exception: null,
        file: 'src/cheques/cheques.controller.ts',
        method: 'update',
        line: 53,
        incomingUrl: request.originalUrl,
        pathParameter: id,
        requestBody: request.body,
        validatedDto: updateChequeDto,
      }),
    );

    return this.chequesService.update(
      id,
      updateChequeDto,
    ).catch((error: unknown) => {
      const statusCode =
        error instanceof HttpException
          ? error.getStatus()
          : response.statusCode || 500;

      const exceptionName =
        error instanceof Error
          ? error.name
          : 'UnknownException';

      const stackTrace =
        error instanceof Error
          ? error.stack
          : null;

      console.error(
        JSON.stringify({
          requestReceived: 'yes',
          responseStatus: statusCode,
          exception: exceptionName,
          file: 'src/cheques/cheques.controller.ts',
          method: 'update',
          line: 87,
          stackTrace,
        }),
      );

      throw error;
    });
  }

  @Delete(':id')
  remove(
    @Param('id') id: string,
  ) {
    return this.chequesService.remove(id);
  }
}
