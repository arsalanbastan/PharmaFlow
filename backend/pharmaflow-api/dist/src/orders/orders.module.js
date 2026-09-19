"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../auth/auth.module");
const push_module_1 = require("../push/push.module");
const orders_controller_1 = require("./orders.controller");
const order_photo_storage_service_1 = require("./order-photo-storage.service");
const orders_availability_guard_1 = require("./orders-availability.guard");
const orders_service_1 = require("./orders.service");
let OrdersModule = class OrdersModule {
};
exports.OrdersModule = OrdersModule;
exports.OrdersModule = OrdersModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule, push_module_1.PushModule],
        controllers: [orders_controller_1.OrdersController],
        providers: [orders_service_1.OrdersService, order_photo_storage_service_1.OrderPhotoStorageService, orders_availability_guard_1.OrdersAvailabilityGuard],
        exports: [orders_service_1.OrdersService],
    })
], OrdersModule);
//# sourceMappingURL=orders.module.js.map