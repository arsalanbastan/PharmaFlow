"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.SalesInvoicesController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const create_sales_invoice_dto_1 = require("./dto/create-sales-invoice.dto");
const update_sales_invoice_profile_dto_1 = require("./dto/update-sales-invoice-profile.dto");
const sales_invoices_service_1 = require("./sales-invoices.service");
let SalesInvoicesController = class SalesInvoicesController {
    salesInvoices;
    constructor(salesInvoices) {
        this.salesInvoices = salesInvoices;
    }
    findAll(q, page, pageSize) {
        return this.salesInvoices.findAll({ q, page, pageSize });
    }
    profile() {
        return this.salesInvoices.profile();
    }
    updateProfile(dto) {
        return this.salesInvoices.updateProfile(dto);
    }
    create(dto) {
        return this.salesInvoices.create(dto);
    }
    findOne(id) {
        return this.salesInvoices.findOne(id);
    }
};
exports.SalesInvoicesController = SalesInvoicesController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('page')),
    __param(2, (0, common_1.Query)('pageSize')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], SalesInvoicesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('profile'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], SalesInvoicesController.prototype, "profile", null);
__decorate([
    (0, common_1.Put)('profile'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [update_sales_invoice_profile_dto_1.UpdateSalesInvoiceProfileDto]),
    __metadata("design:returntype", void 0)
], SalesInvoicesController.prototype, "updateProfile", null);
__decorate([
    (0, common_1.Post)(),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_sales_invoice_dto_1.CreateSalesInvoiceDto]),
    __metadata("design:returntype", void 0)
], SalesInvoicesController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], SalesInvoicesController.prototype, "findOne", null);
exports.SalesInvoicesController = SalesInvoicesController = __decorate([
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('api/v1/sales-invoices'),
    __metadata("design:paramtypes", [sales_invoices_service_1.SalesInvoicesService])
], SalesInvoicesController);
//# sourceMappingURL=sales-invoices.controller.js.map