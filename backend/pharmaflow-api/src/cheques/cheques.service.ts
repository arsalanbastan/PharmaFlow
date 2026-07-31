import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { CreateChequeDto } from './dto/create-cheque.dto';
import { UpdateChequeDto } from './dto/update-cheque.dto';

@Injectable()
export class ChequesService {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  private async prepareDuplicateWarningContext(
    bankAccountId: string,
    chequeNumber: string,
    excludeId?: string,
  ) {
    return this.prisma.cheque.findMany({
      where: {
        bankAccountId,
        chequeNumber,
        deletedAt: null,
        ...(excludeId
          ? {
              id: {
                not: excludeId,
              },
            }
          : {}),
      },
      orderBy: {
        createdAt: 'desc',
      },
      select: {
        id: true,
        chequeNumber: true,
        amount: true,
        chequeDate: true,
        companyId: true,
        bankAccountId: true,
      },
    });
  }

  async create(createChequeDto: CreateChequeDto) {
    await this.prepareDuplicateWarningContext(
      createChequeDto.bankAccountId,
      createChequeDto.chequeNumber,
    );

    return this.prisma.cheque.create({
      data: {
        ...createChequeDto,
        chequeDate: new Date(createChequeDto.chequeDate),
        ...(createChequeDto.dueDate
          ? { dueDate: new Date(createChequeDto.dueDate) }
          : {}),
      },
    });
  }

  async findAll() {
    return this.prisma.cheque.findMany({
      where: {
        deletedAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async findOne(id: string) {
    return this.prisma.cheque.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });
  }

  async update(
    id: string,
    updateChequeDto: UpdateChequeDto,
  ) {
    const existingCheque = await this.prisma.cheque.findFirst({
      where: {
        id,
        deletedAt: null,
      },
    });

    if (existingCheque) {
      await this.prepareDuplicateWarningContext(
        updateChequeDto.bankAccountId ?? existingCheque.bankAccountId,
        updateChequeDto.chequeNumber ?? existingCheque.chequeNumber,
        id,
      );
    }

    return this.prisma.cheque.update({
      where: {
        id,
      },
      data: {
        ...updateChequeDto,
        ...(updateChequeDto.chequeDate
          ? { chequeDate: new Date(updateChequeDto.chequeDate) }
          : {}),
        ...(updateChequeDto.dueDate
          ? { dueDate: new Date(updateChequeDto.dueDate) }
          : {}),
      },
    });
  }

  async remove(id: string) {
    return this.prisma.cheque.update({
      where: {
        id,
      },
      data: {
        deletedAt: new Date(),
      },
    });
  }
}
