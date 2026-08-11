import { Controller, Get, Res } from '@nestjs/common';
import type { Response } from 'express';
import { PrismaService } from '../database/prisma/prisma.service';

const SERVICE_NAME = 'pharmaflow-api';
const API_VERSION = '1.0.0';

@Controller('api/v1/health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  async check(@Res({ passthrough: true }) response: Response) {
    const serverTime = new Date().toISOString();
    const environment = process.env.NODE_ENV?.trim() || 'development';

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      response.status(200);

      return {
        status: 'ok',
        service: SERVICE_NAME,
        version: API_VERSION,
        environment,
        database: {
          status: 'connected',
        },
        serverTime,
        timestamp: serverTime,
      };
    } catch (error) {
      response.status(503);

      return {
        status: 'degraded',
        service: SERVICE_NAME,
        version: API_VERSION,
        environment,
        database: {
          status: 'error',
        },
        serverTime,
        timestamp: serverTime,
      };
    }
  }
}