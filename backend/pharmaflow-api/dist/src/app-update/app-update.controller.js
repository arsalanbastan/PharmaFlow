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
exports.AppUpdateController = void 0;
const common_1 = require("@nestjs/common");
const app_update_service_1 = require("./app-update.service");
let AppUpdateController = class AppUpdateController {
    appUpdateService;
    constructor(appUpdateService) {
        this.appUpdateService = appUpdateService;
    }
    getAndroidManifest() {
        return this.appUpdateService.getAndroidManifest();
    }
};
exports.AppUpdateController = AppUpdateController;
__decorate([
    (0, common_1.Get)('android'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], AppUpdateController.prototype, "getAndroidManifest", null);
exports.AppUpdateController = AppUpdateController = __decorate([
    (0, common_1.Controller)('api/v1/app-update'),
    __metadata("design:paramtypes", [app_update_service_1.AppUpdateService])
], AppUpdateController);
//# sourceMappingURL=app-update.controller.js.map