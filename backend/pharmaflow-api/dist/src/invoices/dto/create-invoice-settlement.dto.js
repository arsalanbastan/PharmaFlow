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
Object.defineProperty(exports, "__esModule", { value: true });
exports.CreateInvoiceSettlementDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
class InvoiceSettlementChequeDto {
    amount;
    bankAccountId;
    chequeNumber;
    chequeDate;
    dueDate;
    description;
}
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsNumber)({ maxDecimalPlaces: 4 }),
    (0, class_validator_1.Min)(0.0001),
    __metadata("design:type", Number)
], InvoiceSettlementChequeDto.prototype, "amount", void 0);
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], InvoiceSettlementChequeDto.prototype, "bankAccountId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(100),
    __metadata("design:type", String)
], InvoiceSettlementChequeDto.prototype, "chequeNumber", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], InvoiceSettlementChequeDto.prototype, "chequeDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], InvoiceSettlementChequeDto.prototype, "dueDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(1000),
    __metadata("design:type", String)
], InvoiceSettlementChequeDto.prototype, "description", void 0);
class InvoiceSettlementCashDto {
    amount;
    bankAccountId;
    paymentDate;
    paymentMethod;
    trackingNumber;
    description;
}
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsNumber)({ maxDecimalPlaces: 4 }),
    (0, class_validator_1.Min)(0.0001),
    __metadata("design:type", Number)
], InvoiceSettlementCashDto.prototype, "amount", void 0);
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], InvoiceSettlementCashDto.prototype, "bankAccountId", void 0);
__decorate([
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], InvoiceSettlementCashDto.prototype, "paymentDate", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['BANK_DEPOSIT', 'POS_PAYMENT']),
    __metadata("design:type", String)
], InvoiceSettlementCashDto.prototype, "paymentMethod", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(100),
    __metadata("design:type", String)
], InvoiceSettlementCashDto.prototype, "trackingNumber", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(1000),
    __metadata("design:type", String)
], InvoiceSettlementCashDto.prototype, "description", void 0);
class CreateInvoiceSettlementDto {
    invoiceIds;
    cheque;
    cash;
    discountAmount;
    discountDescription;
    notes;
}
exports.CreateInvoiceSettlementDto = CreateInvoiceSettlementDto;
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMinSize)(1),
    (0, class_validator_1.ArrayMaxSize)(200),
    (0, class_validator_1.IsUUID)('4', { each: true }),
    __metadata("design:type", Array)
], CreateInvoiceSettlementDto.prototype, "invoiceIds", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.ValidateNested)(),
    (0, class_transformer_1.Type)(() => InvoiceSettlementChequeDto),
    __metadata("design:type", InvoiceSettlementChequeDto)
], CreateInvoiceSettlementDto.prototype, "cheque", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.ValidateNested)(),
    (0, class_transformer_1.Type)(() => InvoiceSettlementCashDto),
    __metadata("design:type", InvoiceSettlementCashDto)
], CreateInvoiceSettlementDto.prototype, "cash", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsNumber)({ maxDecimalPlaces: 4 }),
    (0, class_validator_1.Min)(0),
    __metadata("design:type", Number)
], CreateInvoiceSettlementDto.prototype, "discountAmount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(1000),
    __metadata("design:type", String)
], CreateInvoiceSettlementDto.prototype, "discountDescription", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(1000),
    __metadata("design:type", String)
], CreateInvoiceSettlementDto.prototype, "notes", void 0);
//# sourceMappingURL=create-invoice-settlement.dto.js.map