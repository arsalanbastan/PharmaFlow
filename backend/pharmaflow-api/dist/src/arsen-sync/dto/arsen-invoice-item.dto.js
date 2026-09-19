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
exports.ArsenInvoiceItemDto = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
const BIGINT_TEXT = /^\d{1,20}$/;
const MONEY_TEXT = /^-?\d{1,16}(?:\.\d{1,4})?$/;
class ArsenInvoiceItemDto {
    arsenFactorDetailId;
    arsenFactorDetailsId;
    arsenDrugId;
    drugName;
    barcode;
    packetQuantity;
    quantity;
    salePrice;
    purchasePrice;
    rowDiscount;
    hasTax;
    expireDate;
    expireDateGregorian;
    batchNumber;
}
exports.ArsenInvoiceItemDto = ArsenInvoiceItemDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(BIGINT_TEXT),
    __metadata("design:type", String)
], ArsenInvoiceItemDto.prototype, "arsenFactorDetailId", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(2147483647),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "arsenFactorDetailsId", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(BIGINT_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "arsenDrugId", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(500),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "drugName", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "barcode", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(-2147483648),
    (0, class_validator_1.Max)(2147483647),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "packetQuantity", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsNumber)({ allowInfinity: false, allowNaN: false }),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "quantity", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "salePrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "purchasePrice", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Matches)(MONEY_TEXT),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "rowDiscount", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(2147483647),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "hasTax", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(100),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "expireDate", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "expireDateGregorian", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", Object)
], ArsenInvoiceItemDto.prototype, "batchNumber", void 0);
//# sourceMappingURL=arsen-invoice-item.dto.js.map