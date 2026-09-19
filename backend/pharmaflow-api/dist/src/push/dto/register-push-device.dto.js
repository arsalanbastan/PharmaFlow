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
exports.RegisterPushDeviceDto = void 0;
const class_validator_1 = require("class-validator");
class RegisterPushDeviceDto {
    token;
    installationId;
    platform;
    appPackage;
    notificationAggregationVersion;
}
exports.RegisterPushDeviceDto = RegisterPushDeviceDto;
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(16),
    (0, class_validator_1.MaxLength)(4096),
    __metadata("design:type", String)
], RegisterPushDeviceDto.prototype, "token", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.MinLength)(8),
    (0, class_validator_1.MaxLength)(200),
    __metadata("design:type", String)
], RegisterPushDeviceDto.prototype, "installationId", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['android']),
    __metadata("design:type", String)
], RegisterPushDeviceDto.prototype, "platform", void 0);
__decorate([
    (0, class_validator_1.IsIn)(['com.example.pharmaflow', 'com.example.pharmaflow.dev']),
    __metadata("design:type", String)
], RegisterPushDeviceDto.prototype, "appPackage", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsInt)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(1),
    __metadata("design:type", Number)
], RegisterPushDeviceDto.prototype, "notificationAggregationVersion", void 0);
//# sourceMappingURL=register-push-device.dto.js.map