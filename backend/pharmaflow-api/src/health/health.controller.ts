import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';

const SERVICE_NAME = 'pharmaflow-api';
const API_VERSION = '1.0.0';

@Controller('api/v1/health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  async check() {
    let databaseStatus = 'disconnected';

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      databaseStatus = 'connected';
    } catch (error) {
      databaseStatus = 'error';
    }

    const serverTime = new Date().toISOString();
    const environment = process.env.NODE_ENV?.trim() || 'development';

    return {
      status: 'ok',
      service: SERVICE_NAME,
      version: API_VERSION,
      environment,
      database: {
        status: databaseStatus,
      },
      serverTime,
      timestamp: serverTime,
    };
  }
}