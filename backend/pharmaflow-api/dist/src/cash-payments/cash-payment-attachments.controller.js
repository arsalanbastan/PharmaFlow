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
exports.CashPaymentAttachmentsController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const permissions_decorator_1 = require("../auth/permissions.decorator");
const permissions_guard_1 = require("../auth/permissions.guard");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const cash_payment_attachments_service_1 = require("./cash-payment-attachments.service");
const confirm_cash_payment_attachment_dto_1 = require("./dto/confirm-cash-payment-attachment.dto");
const prepare_cash_payment_attachment_dto_1 = require("./dto/prepare-cash-payment-attachment.dto");
let CashPaymentAttachmentsController = class CashPaymentAttachmentsController {
    attachmentsService;
    constructor(attachmentsService) {
        this.attachmentsService = attachmentsService;
    }
    prepareUpload(dto) {
        return this.attachmentsService.prepareUpload(dto);
    }
    confirmUpload(dto) {
        return this.attachmentsService.confirmUpload(dto);
    }
    findAll(cashPaymentId) {
        return this.attachmentsService.findAll(cashPaymentId);
    }
    findChanges(updatedAfter, afterId, limit) {
        return this.attachmentsService.findChanges({
            updatedAfter,
            afterId,
            limit,
        });
    }
    createDownloadUrl(id) {
        return this.attachmentsService.createDownloadUrl(id);
    }
    remove(id) {
        return this.attachmentsService.remove(id);
    }
};
exports.CashPaymentAttachmentsController = CashPaymentAttachmentsController;
__decorate([
    (0, common_1.Post)('prepare-upload'),
    (0, permissions_decorator_1.Permissions)('canCreateCashPayments'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, permissions_guard_1.PermissionsGuard),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [prepare_cash_payment_attachment_dto_1.PrepareCashPaymentAttachmentDto]),
    __metadata("design:returntype", void 0)
], CashPaymentAttachmentsController.prototype, "prepareUpload", null);
__decorate([
    (0, common_1.Post)('confirm'),
    (0, permissions_decorator_1.Permissions)('canCreateCashPayments'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, permissions_guard_1.PermissionsGuard),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [confirm_cash_payment_attachment_dto_1.ConfirmCashPaymentAttachmentDto]),
    __metadata("design:returntype", void 0)
], CashPaymentAttachmentsController.prototype, "confirmUpload", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('cashPaymentId')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CashPaymentAttachmentsController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('changes'),
    __param(0, (0, common_1.Query)('updatedAfter')),
    __param(1, (0, common_1.Query)('afterId')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], CashPaymentAttachmentsController.prototype, "findChanges", null);
__decorate([
    (0, common_1.Get)(':id/download-url'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CashPaymentAttachmentsController.prototype, "createDownloadUrl", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], CashPaymentAttachmentsController.prototype, "remove", null);
exports.CashPaymentAttachmentsController = CashPaymentAttachmentsController = __decorate([
    (0, common_1.Controller)('api/v1/cash-payment-attachments'),
    __metadata("design:paramtypes", [cash_payment_attachments_service_1.CashPaymentAttachmentsService])
], CashPaymentAttachmentsController);
//# sourceMappingURL=cash-payment-attachments.controller.js.map