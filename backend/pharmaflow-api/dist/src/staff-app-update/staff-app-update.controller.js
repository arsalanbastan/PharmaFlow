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
exports.StaffAppUpdateController = void 0;
const common_1 = require("@nestjs/common");
const staff_app_update_service_1 = require("./staff-app-update.service");
let StaffAppUpdateController = class StaffAppUpdateController {
    service;
    constructor(service) {
        this.service = service;
    }
    getAndroidManifest() {
        return this.service.getAndroidManifest();
    }
};
exports.StaffAppUpdateController = StaffAppUpdateController;
__decorate([
    (0, common_1.Get)('android'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], StaffAppUpdateController.prototype, "getAndroidManifest", null);
exports.StaffAppUpdateController = StaffAppUpdateController = __decorate([
    (0, common_1.Controller)('api/v1/app-update/staff'),
    __metadata("design:paramtypes", [staff_app_update_service_1.StaffAppUpdateService])
], StaffAppUpdateController);
//# sourceMappingURL=staff-app-update.controller.js.map