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
exports.ChequesController = void 0;
const common_1 = require("@nestjs/common");
const auth_guard_1 = require("../auth/auth.guard");
const permissions_decorator_1 = require("../auth/permissions.decorator");
const permissions_guard_1 = require("../auth/permissions.guard");
const roles_decorator_1 = require("../auth/roles.decorator");
const roles_guard_1 = require("../auth/roles.guard");
const cheques_service_1 = require("./cheques.service");
const create_cheque_dto_1 = require("./dto/create-cheque.dto");
const update_cheque_dto_1 = require("./dto/update-cheque.dto");
let ChequesController = class ChequesController {
    chequesService;
    constructor(chequesService) {
        this.chequesService = chequesService;
    }
    create(createChequeDto) {
        return this.chequesService.create(createChequeDto);
    }
    findAll() {
        return this.chequesService.findAll();
    }
    findChanges(updatedAfter, afterId, limit) {
        return this.chequesService.findChanges({
            updatedAfter,
            afterId,
            limit,
        });
    }
    findOne(id) {
        return this.chequesService.findOne(id);
    }
    update(id, updateChequeDto) {
        return this.chequesService.update(id, updateChequeDto);
    }
    remove(uuid) {
        return this.chequesService.remove(uuid);
    }
};
exports.ChequesController = ChequesController;
__decorate([
    (0, common_1.Post)(),
    (0, permissions_decorator_1.Permissions)('canCreateCheques'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, permissions_guard_1.PermissionsGuard),
    __param(0, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [create_cheque_dto_1.CreateChequeDto]),
    __metadata("design:returntype", void 0)
], ChequesController.prototype, "create", null);
__decorate([
    (0, common_1.Get)(),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", void 0)
], ChequesController.prototype, "findAll", null);
__decorate([
    (0, common_1.Get)('changes'),
    __param(0, (0, common_1.Query)('updatedAfter')),
    __param(1, (0, common_1.Query)('afterId')),
    __param(2, (0, common_1.Query)('limit')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, String, String]),
    __metadata("design:returntype", void 0)
], ChequesController.prototype, "findChanges", null);
__decorate([
    (0, common_1.Get)(':id'),
    __param(0, (0, common_1.Param)('id')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], ChequesController.prototype, "findOne", null);
__decorate([
    (0, common_1.Patch)(':id'),
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    __param(0, (0, common_1.Param)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, update_cheque_dto_1.UpdateChequeDto]),
    __metadata("design:returntype", void 0)
], ChequesController.prototype, "update", null);
__decorate([
    (0, common_1.Delete)(':uuid'),
    (0, common_1.HttpCode)(common_1.HttpStatus.NO_CONTENT),
    (0, roles_decorator_1.Roles)('MANAGER'),
    (0, common_1.UseGuards)(auth_guard_1.AuthGuard, roles_guard_1.RolesGuard),
    __param(0, (0, common_1.Param)('uuid')),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String]),
    __metadata("design:returntype", void 0)
], ChequesController.prototype, "remove", null);
exports.ChequesController = ChequesController = __decorate([
    (0, common_1.Controller)('api/v1/cheques'),
    __metadata("design:paramtypes", [cheques_service_1.ChequesService])
], ChequesController);
//# sourceMappingURL=cheques.controller.js.map