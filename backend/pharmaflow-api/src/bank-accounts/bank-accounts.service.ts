import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { CreateBankAccountDto } from './dto/create-bank-account.dto';
import { UpdateBankAccountDto } from './dto/update-bank-account.dto';

@Injectable()
export class BankAccountsService {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  async create(createBankAccountDto: CreateBankAccountDto) {
    return this.prisma.bankAccount.create({
      data: createBankAccountDto,
    });
  }

  async findAll() {
    return this.prisma.bankAccount.findMany({
      where: {
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async findOne(id: string) {
    return this.prisma.bankAccount.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
  }

  async update(
    id: string,
    updateBankAccountDto: UpdateBankAccountDto,
  ) {
    return this.prisma.bankAccount.update({
      where: {
        id,
      },
      data: updateBankAccountDto,
    });
  }

  async remove(id: string) {
    return this.prisma.bankAccount.update({
      where: {
        id,
      },
      data: {
        deletedAt: new Date(),
      },
    });
  }
}
