"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.StaffAppUpdateModule = void 0;
const common_1 = require("@nestjs/common");
const staff_app_update_controller_1 = require("./staff-app-update.controller");
const staff_app_update_service_1 = require("./staff-app-update.service");
const staff_app_update_storage_service_1 = require("./staff-app-update-storage.service");
let StaffAppUpdateModule = class StaffAppUpdateModule {
};
exports.StaffAppUpdateModule = StaffAppUpdateModule;
exports.StaffAppUpdateModule = StaffAppUpdateModule = __decorate([
    (0, common_1.Module)({
        controllers: [staff_app_update_controller_1.StaffAppUpdateController],
        providers: [
            staff_app_update_service_1.StaffAppUpdateService,
            staff_app_update_storage_service_1.StaffAppUpdateStorageService,
        ],
    })
], StaffAppUpdateModule);
//# sourceMappingURL=staff-app-update.module.js.map