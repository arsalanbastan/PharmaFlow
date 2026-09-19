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
exports.UploadWebOrderPhotoDto = void 0;
const class_validator_1 = require("class-validator");
const class_transformer_1 = require("class-transformer");
const MAX_JPEG_BASE64_LENGTH = 273068;
class UploadWebOrderPhotoDto {
    mimeType;
    fileSize;
    sha256;
    imageBase64;
}
exports.UploadWebOrderPhotoDto = UploadWebOrderPhotoDto;
__decorate([
    (0, class_validator_1.Equals)('image/jpeg'),
    __metadata("design:type", String)
], UploadWebOrderPhotoDto.prototype, "mimeType", void 0);
__decorate([
    (0, class_transformer_1.Type)(() => Number),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(1),
    (0, class_validator_1.Max)(204800),
    __metadata("design:type", Number)
], UploadWebOrderPhotoDto.prototype, "fileSize", void 0);
__decorate([
    (0, class_validator_1.Matches)(/^[a-fA-F0-9]{64}$/),
    __metadata("design:type", String)
], UploadWebOrderPhotoDto.prototype, "sha256", void 0);
__decorate([
    (0, class_validator_1.IsBase64)(),
    (0, class_validator_1.MaxLength)(MAX_JPEG_BASE64_LENGTH),
    __metadata("design:type", String)
], UploadWebOrderPhotoDto.prototype, "imageBase64", void 0);
//# sourceMappingURL=upload-web-order-photo.dto.js.map