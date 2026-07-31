import { Injectable } from '@nestjs/common';
import { PrismaService } from './database/prisma/prisma.service';

@Injectable()
export class AppService {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  async getHello() {
    const companies = await this.prisma.company.findMany();

    return {
      message: 'PharmaFlow Backend is running',
      companies,
    };
  }
}