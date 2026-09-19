"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.CashPaymentsModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../auth/auth.module");
const cash_payment_attachments_controller_1 = require("./cash-payment-attachments.controller");
const cash_payment_attachment_storage_service_1 = require("./cash-payment-attachment-storage.service");
const cash_payment_attachments_service_1 = require("./cash-payment-attachments.service");
const cash_payments_controller_1 = require("./cash-payments.controller");
const cash_payments_service_1 = require("./cash-payments.service");
let CashPaymentsModule = class CashPaymentsModule {
};
exports.CashPaymentsModule = CashPaymentsModule;
exports.CashPaymentsModule = CashPaymentsModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule],
        controllers: [cash_payments_controller_1.CashPaymentsController, cash_payment_attachments_controller_1.CashPaymentAttachmentsController],
        providers: [
            cash_payments_service_1.CashPaymentsService,
            cash_payment_attachments_service_1.CashPaymentAttachmentsService,
            cash_payment_attachment_storage_service_1.CashPaymentAttachmentStorageService,
        ],
        exports: [cash_payments_service_1.CashPaymentsService, cash_payment_attachments_service_1.CashPaymentAttachmentsService],
    })
], CashPaymentsModule);
//# sourceMappingURL=cash-payments.module.js.map