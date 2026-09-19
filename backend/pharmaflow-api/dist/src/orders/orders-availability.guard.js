"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.OrdersAvailabilityGuard = void 0;
const common_1 = require("@nestjs/common");
let OrdersAvailabilityGuard = class OrdersAvailabilityGuard {
    canActivate(_context) {
        const enabled = process.env.ORDERS_API_ENABLED?.trim().toLowerCase() === 'true';
        if (!enabled) {
            throw new common_1.ServiceUnavailableException('Orders API is not enabled yet.');
        }
        return true;
    }
};
exports.OrdersAvailabilityGuard = OrdersAvailabilityGuard;
exports.OrdersAvailabilityGuard = OrdersAvailabilityGuard = __decorate([
    (0, common_1.Injectable)()
], OrdersAvailabilityGuard);
//# sourceMappingURL=orders-availability.guard.js.map