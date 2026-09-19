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
exports.ArsenInvoiceDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
const arsen_invoice_item_dto_1 = require("./arsen-invoice-item.dto");
const MONEY_TEXT = /^-?\d{1,16}(?:\.\d{1,4})?$/;
class ArsenInvoiceDto {
    arsenFactorId;
    invoiceNumber;
    invoiceDate;
    docDate;
    settlementDate;
    description;
    factorDocType;
    factorDocTypeName;
    factorType;
    factorTypeName;
    factorItemType;
    arsenBusinessPartnerId;
    arsenBusinessPartnerName;
    factorTotalPrice;
    factorDiscount;
    factorTax;
    factorPayablePrice;
    barbariPrice;
    paymentDays;
    isDeletedInArsen;
    isLockedInArsen;
    arsenSaveDateTime;
    items;
}
exports.ArsenInvoiceDto = ArsenInvoiceDto;
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(2147483647),
    __metadata("design:type", Number)
], ArsenInvoiceDto.prototype, "arsenFactorId", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "invoiceNumber", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(20),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "invoiceDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(20),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "docDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(20),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "settlementDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(1000),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "description", void 0);
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsIn)([1, 2]),
    __metadata("design:type", Number)
], ArsenInvoiceDto.prototype, "factorDocType", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorDocTypeName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorType", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorTypeName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorItemType", void 0);
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(2147483647),
    __metadata("design:type", Number)
], ArsenInvoiceDto.prototype, "arsenBusinessPartnerId", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(500),
    __metadata("design:type", String)
], ArsenInvoiceDto.prototype, "arsenBusinessPartnerName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorTotalPrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorDiscount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorTax", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "factorPayablePrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "barbariPrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(36500),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "paymentDays", void 0);
__decorate([
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ArsenInvoiceDto.prototype, "isDeletedInArsen", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "isLockedInArsen", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Object)
], ArsenInvoiceDto.prototype, "arsenSaveDateTime", void 0);
__decorate([
    (0, class_validator_1.IsArray)(),
    (0, class_validator_1.ArrayMaxSize)(5000),
    (0, class_validator_1.ValidateNested)({ each: true }),
    (0, class_transformer_1.Type)(() => arsen_invoice_item_dto_1.ArsenInvoiceItemDto),
    __metadata("design:type", Array)
], ArsenInvoiceDto.prototype, "items", void 0);
//# sourceMappingURL=arsen-invoice.dto.js.map