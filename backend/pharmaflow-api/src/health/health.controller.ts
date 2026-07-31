import { Controller, Get } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';

@Controller('api/v1/health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  @Get()
  async check() {
    let database = 'disconnected';

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      database = 'connected';
    } catch (error) {
      database = 'error';
    }

    return {
      status: 'ok',
      database,
      timestamp: new Date().toISOString(),
    };
  }
}