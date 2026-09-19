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
exports.PrepareChequeAttachmentDto = exports.MAX_CHEQUE_ATTACHMENT_BYTES = void 0;
const class_transformer_1 = require("class-transformer");
const class_validator_1 = require("class-validator");
const cheque_constants_1 = require("../cheque.constants");
exports.MAX_CHEQUE_ATTACHMENT_BYTES = 25 * 1024 * 1024;
class PrepareChequeAttachmentDto {
    id;
    chequeId;
    kind;
    fileName;
    mimeType;
    originalFileSize;
    fileSize;
    sha256;
}
exports.PrepareChequeAttachmentDto = PrepareChequeAttachmentDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], PrepareChequeAttachmentDto.prototype, "id", void 0);
__decorate([
    (0, class_validator_1.IsUUID)(),
    __metadata("design:type", String)
], PrepareChequeAttachmentDto.prototype, "chequeId", void 0);
__decorate([
    (0, class_validator_1.IsIn)(cheque_constants_1.CHEQUE_ATTACHMENT_KINDS),
    __metadata("design:type", String)
], PrepareChequeAttachmentDto.prototype, "kind", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    __metadata("design:type", String)
], PrepareChequeAttachmentDto.prototype, "fileName", void 0);
__decorate([
    (0, class_validator_1.IsMimeType)(),
    __metadata("design:type", String)
], PrepareChequeAttachmentDto.prototype, "mimeType", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(exports.MAX_CHEQUE_ATTACHMENT_BYTES),
    __metadata("design:type", Number)
], PrepareChequeAttachmentDto.prototype, "originalFileSize", void 0);
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(exports.MAX_CHEQUE_ATTACHMENT_BYTES),
    __metadata("design:type", Number)
], PrepareChequeAttachmentDto.prototype, "fileSize", void 0);
__decorate([
    (0, class_validator_1.Matches)(/^[0-9a-fA-F]{64}$/),
    __metadata("design:type", String)
], PrepareChequeAttachmentDto.prototype, "sha256", void 0);
//# sourceMappingURL=prepare-cheque-attachment.dto.js.map