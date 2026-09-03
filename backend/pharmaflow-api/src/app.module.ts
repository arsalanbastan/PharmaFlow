import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { PrismaModule } from './database/prisma/prisma.module';
import { HealthModule } from './health/health.module';
import { CompaniesModule } from './companies/companies.module';
import { BankAccountsModule } from './bank-accounts/bank-accounts.module';
import { ChequesModule } from './cheques/cheques.module';
import { CashPaymentsModule } from './cash-payments/cash-payments.module';
import { AdminModule } from './admin/admin.module';
import { AuditModule } from './audit/audit.module';
import { AppUpdateModule } from './app-update/app-update.module';

import { OrdersModule } from './orders/orders.module';
import { InvoicesModule } from './invoices/invoices.module';

import { StaffAppUpdateModule } from './staff-app-update/staff-app-update.module';
import { AuthModule } from './auth/auth.module';
import { ArsenSyncModule } from './arsen-sync/arsen-sync.module';

@Module({
  imports: [
    PrismaModule,
    HealthModule,
    CompaniesModule,
    BankAccountsModule,
    ChequesModule,
    CashPaymentsModule,
    AdminModule,
    AuditModule,
    AppUpdateModule,
    OrdersModule,
    InvoicesModule,
    StaffAppUpdateModule,
    AuthModule,
    ArsenSyncModule,
  ],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
