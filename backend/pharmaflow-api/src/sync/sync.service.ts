import { Injectable } from '@nestjs/common';
import { PrismaService } from '../database/prisma/prisma.service';
import { SyncChequesDto, SyncChequeDto } from './dto/sync-cheques.dto';

type SyncChequeError = {
  index: number;
  chequeNumber?: string;
  reason: string;
};

type SyncChequesResult = {
  received: number;
  created: number;
  alreadyExists: number;
  failed: number;
  errors: SyncChequeError[];
};

@Injectable()
export class SyncService {
  constructor(
    private readonly prisma: PrismaService,
  ) {}

  private async companyExists(companyId: string) {
    return this.prisma.company.findFirst({
      where: {
        id: companyId,
        deletedAt: null,
      },
      select: {
        id: true,
      },
    });
  }

  private async bankAccountExists(bankAccountId: string) {
    return this.prisma.bankAccount.findFirst({
      where: {
        id: bankAccountId,
        deletedAt: null,
      },
      select: {
        id: true,
      },
    });
  }

  private async chequeExists(item: SyncChequeDto) {
    return this.prisma.cheque.findFirst({
      where: {
        bankAccountId: item.bankAccountId,
        chequeNumber: item.chequeNumber,
        deletedAt: null,
      },
      select: {
        id: true,
      },
    });
  }

  async syncCheques(
    syncChequesDto: SyncChequesDto,
  ): Promise<SyncChequesResult> {
    const result: SyncChequesResult = {
      received: syncChequesDto.cheques.length,
      created: 0,
      alreadyExists: 0,
      failed: 0,
      errors: [],
    };

    for (const [index, cheque] of syncChequesDto.cheques.entries()) {
      const companyExists = await this.companyExists(cheque.companyId);

      if (!companyExists) {
        result.failed += 1;
        result.errors.push({
          index,
          chequeNumber: cheque.chequeNumber,
          reason: 'company_not_found',
        });
        continue;
      }

      const bankAccountExists = await this.bankAccountExists(cheque.bankAccountId);

      if (!bankAccountExists) {
        result.failed += 1;
        result.errors.push({
          index,
          chequeNumber: cheque.chequeNumber,
          reason: 'bank_account_not_found',
        });
        continue;
      }

      const existingCheque = await this.chequeExists(cheque);

      if (existingCheque) {
        result.alreadyExists += 1;
        continue;
      }

      try {
        await this.prisma.cheque.create({
          data: {
            chequeNumber: cheque.chequeNumber,
            amount: cheque.amount,
            chequeDate: new Date(cheque.chequeDate),
            companyId: cheque.companyId,
            bankAccountId: cheque.bankAccountId,
            description: cheque.description,
          },
        });

        result.created += 1;
      } catch {
        result.failed += 1;
        result.errors.push({
          index,
          chequeNumber: cheque.chequeNumber,
          reason: 'create_failed',
        });
      }
    }

    return result;
  }
}