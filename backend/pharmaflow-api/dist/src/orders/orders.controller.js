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
exports.OrdersController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const permissions_decorator_1 = require("../auth/permissions.decorator");
const permissions_guard_1 = require("../auth/permissions.guard");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const assign_order_request_dto_1 = require("./dto/assign-order-request.dto");
const check_order_duplicate_dto_1 = require("./dto/check-order-duplicate.dto");
const confirm_order_photo_dto_1 = require("./dto/confirm-order-photo.dto");
const create_order_request_dto_1 = require("./dto/create-order-request.dto");
const prepare_order_photo_dto_1 = require("./dto/prepare-order-photo.dto");
const update_order_category_dto_1 = require("./dto/update-order-category.dto");
const update_pending_order_request_dto_1 = require("./dto/update-pending-order-request.dto");
const upload_web_order_photo_dto_1 = require("./dto/upload-web-order-photo.dto");
const orders_availability_guard_1 = require("./orders-availability.guard");
const orders_service_1 = require("./orders.service");
let OrdersController = class OrdersController {
    ordersService;
    constructor(ordersService) {
        this.ordersService = ordersService;
    }
    checkDuplicate(dto) {
        return this.ordersService.checkDuplicate(dto);
    }
    create(dto) {
        return this.ordersService.create(dto);
    }
    findAll(status, category) {
        return this.ordersService.findAll({
            status,
            category,
        });
    }
    findChanges(updatedAfter, afterId, limit) {
        return this.ordersService.findChanges({
            updatedAfter,
            afterId,
            limit,
        });
    }
    preparePhotoUpload(id, dto) {
        return this.ordersService.preparePhotoUpload(id, dto);
    }
    confirmPhotoUpload(id, dto) {
        return this.ordersService.confirmPhotoUpload(id, dto);
    }
    uploadWebPhoto(id, dto) {
        return this.ordersService.uploadWebPhoto(id, dto);
    }
    getPhoto(id) {
        return this.ordersService.createPhotoDownload(id);
    }
    findOne(id) {
        return this.ordersService.findOne(id);
    }
    updateCategory(id, dto) {
        return this.ordersService.updateCategory(id, dto);
    }
    updatePending(id, dto) {
        return this.ordersService.updatePending(id, dto);
    }
    assign(id, dto) {
        return this.ordersService.assign(id, dto);
    }
    returnToPending(id) {
        return this.ordersService.returnToPending(id);
    }
    receive(id) {
        return this.ordersService.receive(id);
    }
    cancel(id) {
        return this.ordersService.cancel(id);
    }
    restoreCanceled(id) {
        return this.ordersService.restoreCanceled(id);
    }
    removePending(id) {
        return this.ordersService.removePending(id);
    }
};
exports.OrdersController = OrdersController;
__decorate([
    (0, common_1.Post)('duplicate-check'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [check_order_duplicate_dto_1.CheckOrderDuplicateDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "checkDuplicate", null);
__decorate([
    (0, common_1.Post)(),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_order_request_dto_1.CreateOrderRequestDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    __param(0, (0, common_1.Query)('status')),
    __param(1, (0, common_1.Query)('category')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('changes'),
    __param(0, (0, common_1.Query)('updatedAfter')),
    __param(1, (0, common_1.Query)('afterId')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "findChanges", null);
__decorate([
    (0, common_1.Post)(':id/photo/prepare'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, prepare_order_photo_dto_1.PrepareOrderPhotoDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "preparePhotoUpload", null);
__decorate([
    (0, common_1.Post)(':id/photo/confirm'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, confirm_order_photo_dto_1.ConfirmOrderPhotoDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "confirmPhotoUpload", null);
__decorate([
    (0, common_1.Post)(':id/photo/upload-web'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, upload_web_order_photo_dto_1.UploadWebOrderPhotoDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "uploadWebPhoto", null);
__decorate([
    (0, common_1.Get)(':id/photo'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "getPhoto", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "findOne", null);
__decorate([
    (0, common_1.Post)(':id/category'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_order_category_dto_1.UpdateOrderCategoryDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "updateCategory", null);
__decorate([
    (0, common_1.Post)(':id/edit'),
    (0, roles_decorator_1.Roles)('STAFF', 'MANAGER'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_pending_order_request_dto_1.UpdatePendingOrderRequestDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "updatePending", null);
__decorate([
    (0, common_1.Post)(':id/assign'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, assign_order_request_dto_1.AssignOrderRequestDto]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "assign", null);
__decorate([
    (0, common_1.Post)(':id/return-to-pending'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "returnToPending", null);
__decorate([
    (0, common_1.Post)(':id/receive'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "receive", null);
__decorate([
    (0, common_1.Post)(':id/cancel'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "cancel", null);
__decorate([
    (0, common_1.Post)(':id/restore'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "restoreCanceled", null);
__decorate([
    (0, common_1.Delete)(':id'),
    (0, roles_decorator_1.Roles)('STAFF', 'MANAGER'),
    (0, permissions_decorator_1.Permissions)('canCreateOrders'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], OrdersController.prototype, "removePending", null);
exports.OrdersController = OrdersController = __decorate([
    (0, common_1.UseGuards)(orders_availability_guard_1.OrdersAvailabilityGuard, auth_guard_1.AuthGuard, roles_guard_1.RolesGuard, permissions_guard_1.PermissionsGuard),
    (0, common_1.Controller)('api/v1/orders'),
    __metadata("design:paramtypes", [orders_service_1.OrdersService])
], OrdersController);
//# sourceMappingURL=orders.controller.js.map