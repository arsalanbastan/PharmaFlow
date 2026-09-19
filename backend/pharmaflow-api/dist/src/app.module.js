"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const app_controller_1 = require("./app.controller");
const app_service_1 = require("./app.service");
const prisma_module_1 = require("./database/prisma/prisma.module");
const health_module_1 = require("./health/health.module");
const companies_module_1 = require("./companies/companies.module");
const bank_accounts_module_1 = require("./bank-accounts/bank-accounts.module");
const cheques_module_1 = require("./cheques/cheques.module");
const cash_payments_module_1 = require("./cash-payments/cash-payments.module");
const admin_module_1 = require("./admin/admin.module");
const audit_module_1 = require("./audit/audit.module");
const app_update_module_1 = require("./app-update/app-update.module");
const orders_module_1 = require("./orders/orders.module");
const invoices_module_1 = require("./invoices/invoices.module");
const catalog_module_1 = require("./catalog/catalog.module");
const sales_invoices_module_1 = require("./sales-invoices/sales-invoices.module");
const staff_app_update_module_1 = require("./staff-app-update/staff-app-update.module");
const auth_module_1 = require("./auth/auth.module");
const arsen_sync_module_1 = require("./arsen-sync/arsen-sync.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            prisma_module_1.PrismaModule,
            health_module_1.HealthModule,
            companies_module_1.CompaniesModule,
            bank_accounts_module_1.BankAccountsModule,
            cheques_module_1.ChequesModule,
            cash_payments_module_1.CashPaymentsModule,
            admin_module_1.AdminModule,
            audit_module_1.AuditModule,
            app_update_module_1.AppUpdateModule,
            orders_module_1.OrdersModule,
            invoices_module_1.InvoicesModule,
            catalog_module_1.CatalogModule,
            sales_invoices_module_1.SalesInvoicesModule,
            staff_app_update_module_1.StaffAppUpdateModule,
            auth_module_1.AuthModule,
            arsen_sync_module_1.ArsenSyncModule,
        ],
        controllers: [app_controller_1.AppController],
        providers: [app_service_1.AppService],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map