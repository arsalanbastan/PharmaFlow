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
exports.CashPaymentsController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const permissions_decorator_1 = require("../auth/permissions.decorator");
const permissions_guard_1 = require("../auth/permissions.guard");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const cash_payments_service_1 = require("./cash-payments.service");
const create_cash_payment_dto_1 = require("./dto/create-cash-payment.dto");
const update_cash_payment_dto_1 = require("./dto/update-cash-payment.dto");
let CashPaymentsController = class CashPaymentsController {
    cashPaymentsService;
    constructor(cashPaymentsService) {
        this.cashPaymentsService = cashPaymentsService;
    }
    create(createCashPaymentDto) {
        return this.cashPaymentsService.create(createCashPaymentDto);
    }
    findAll() {
        return this.cashPaymentsService.findAll();
    }
    findChanges(updatedAfter, afterId, limit) {
        return this.cashPaymentsService.findChanges({
            updatedAfter,
            afterId,
            limit,
        });
    }
    findOne(id) {
        return this.cashPaymentsService.findOne(id);
    }
    update(id, updateCashPaymentDto) {
        return this.cashPaymentsService.update(id, updateCashPaymentDto);
    }
    remove(id) {
        return this.cashPaymentsService.remove(id);
    }
};
exports.CashPaymentsController = CashPaymentsController;
__decorate([
    (0, common_1.Post)(),
    (0, permissions_decorator_1.Permissions)('canCreateCashPayments'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, permissions_guard_1.PermissionsGuard),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_cash_payment_dto_1.CreateCashPaymentDto]),
    __metadata("design:returntype", void 0)
], CashPaymentsController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], CashPaymentsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('changes'),
    __param(0, (0, common_1.Query)('updatedAfter')),
    __param(1, (0, common_1.Query)('afterId')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], CashPaymentsController.prototype, "findChanges", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CashPaymentsController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_cash_payment_dto_1.UpdateCashPaymentDto]),
    __metadata("design:returntype", void 0)
], CashPaymentsController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CashPaymentsController.prototype, "remove", null);
exports.CashPaymentsController = CashPaymentsController = __decorate([
    (0, common_1.Controller)('api/v1/cash-payments'),
    __metadata("design:paramtypes", [cash_payments_service_1.CashPaymentsService])
], CashPaymentsController);
//# sourceMappingURL=cash-payments.controller.js.map