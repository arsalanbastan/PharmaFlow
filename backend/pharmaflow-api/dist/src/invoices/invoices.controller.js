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
exports.InvoicesController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const update_invoice_payment_status_dto_1 = require("./dto/update-invoice-payment-status.dto");
const create_invoice_settlement_dto_1 = require("./dto/create-invoice-settlement.dto");
const invoices_service_1 = require("./invoices.service");
let InvoicesController = class InvoicesController {
    invoices;
    constructor(invoices) {
        this.invoices = invoices;
    }
    findAll(q, companyId, dateFrom, dateTo, page, pageSize) {
        return this.invoices.findAll({
            q,
            companyId,
            dateFrom,
            dateTo,
            page,
            pageSize,
        });
    }
    prepareSettlement(invoiceIds) {
        return this.invoices.prepareSettlement(invoiceIds ?? '');
    }
    createSettlement(dto) {
        return this.invoices.createSettlement(dto);
    }
    updatePaymentStatus(id, dto) {
        return this.invoices.updatePaymentStatus(id, dto.isPaid);
    }
    findOne(id) {
        return this.invoices.findOne(id);
    }
};
exports.InvoicesController = InvoicesController;
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('q')),
    __param(1, (0, common_1.Query)('companyId')),
    __param(2, (0, common_1.Query)('dateFrom')),
    __param(3, (0, common_1.Query)('dateTo')),
    __param(4, (0, common_1.Query)('page')),
    __param(5, (0, common_1.Query)('pageSize')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String, String, String, String]),
    __metadata("design:returntype", void 0)
], InvoicesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('settlement/prepare'),
    __param(0, (0, common_1.Query)('invoiceIds')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], InvoicesController.prototype, "prepareSettlement", null);
__decorate([
    (0, common_1.Post)('settlement'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_invoice_settlement_dto_1.CreateInvoiceSettlementDto]),
    __metadata("design:returntype", void 0)
], InvoicesController.prototype, "createSettlement", null);
__decorate([
    (0, common_1.Patch)(':id/payment-status'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_invoice_payment_status_dto_1.UpdateInvoicePaymentStatusDto]),
    __metadata("design:returntype", void 0)
], InvoicesController.prototype, "updatePaymentStatus", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], InvoicesController.prototype, "findOne", null);
exports.InvoicesController = InvoicesController = __decorate([
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('api/v1/invoices'),
    __metadata("design:paramtypes", [invoices_service_1.InvoicesService])
], InvoicesController);
//# sourceMappingURL=invoices.controller.js.map