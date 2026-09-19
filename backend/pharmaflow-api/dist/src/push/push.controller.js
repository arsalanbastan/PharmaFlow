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
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.PushController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const current_user_decorator_1 = require("../auth/current-user.decorator");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const acknowledge_push_notification_dto_1 = require("./dto/acknowledge-push-notification.dto");
const read_push_device_preferences_dto_1 = require("./dto/read-push-device-preferences.dto");
const register_push_device_dto_1 = require("./dto/register-push-device.dto");
const unregister_push_device_dto_1 = require("./dto/unregister-push-device.dto");
const update_push_device_preferences_dto_1 = require("./dto/update-push-device-preferences.dto");
const push_device_service_1 = require("./push-device.service");
let PushController = class PushController {
    pushDevices;
    constructor(pushDevices) {
        this.pushDevices = pushDevices;
    }
    register(user, dto) {
        return this.pushDevices.register(user, dto);
    }
    getPreferences(user, dto) {
        return this.pushDevices.getPreferences(user, dto);
    }
    updatePreferences(user, dto) {
        return this.pushDevices.updatePreferences(user, dto);
    }
    acknowledgeNotification(user, dto) {
        return this.pushDevices.acknowledgeNotification(user, dto);
    }
    acknowledgeAllNotifications(user, dto) {
        return this.pushDevices.acknowledgeAllNotifications(user, dto);
    }
    unregister(user, dto) {
        return this.pushDevices.unregister(user, dto);
    }
};
exports.PushController = PushController;
__decorate([
    (0, common_1.Post)('devices/register'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, register_push_device_dto_1.RegisterPushDeviceDto]),
    __metadata("design:returntype", void 0)
], PushController.prototype, "register", null);
__decorate([
    (0, common_1.Post)('devices/preferences/read'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, read_push_device_preferences_dto_1.ReadPushDevicePreferencesDto]),
    __metadata("design:returntype", void 0)
], PushController.prototype, "getPreferences", null);
__decorate([
    (0, common_1.Patch)('devices/preferences'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, update_push_device_preferences_dto_1.UpdatePushDevicePreferencesDto]),
    __metadata("design:returntype", void 0)
], PushController.prototype, "updatePreferences", null);
__decorate([
    (0, common_1.Post)('notifications/acknowledge'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, acknowledge_push_notification_dto_1.AcknowledgePushNotificationDto]),
    __metadata("design:returntype", void 0)
], PushController.prototype, "acknowledgeNotification", null);
__decorate([
    (0, common_1.Post)('notifications/acknowledge-all'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, read_push_device_preferences_dto_1.ReadPushDevicePreferencesDto]),
    __metadata("design:returntype", void 0)
], PushController.prototype, "acknowledgeAllNotifications", null);
__decorate([
    (0, common_1.Post)('devices/unregister'),
    __param(0, (0, current_user_decorator_1.CurrentUser)()),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [Object, unregister_push_device_dto_1.UnregisterPushDeviceDto]),
    __metadata("design:returntype", void 0)
], PushController.prototype, "unregister", null);
exports.PushController = PushController = __decorate([
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    (0, common_1.Controller)('api/v1/push'),
    __metadata("design:paramtypes", [push_device_service_1.PushDeviceService])
], PushController);
//# sourceMappingURL=push.controller.js.map