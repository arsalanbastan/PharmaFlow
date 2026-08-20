import { Module } from '@nestjs/common';

import { CompaniesModule } from '../companies/companies.module';
import { BankAccountsModule } from '../bank-accounts/bank-accounts.module';
import { ChequesModule } from '../cheques/cheques.module';

import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [CompaniesModule, BankAccountsModule, ChequesModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
