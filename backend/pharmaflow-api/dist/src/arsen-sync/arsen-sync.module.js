"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ArsenSyncModule = void 0;
const common_1 = require("@nestjs/common");
const arsen_sync_controller_1 = require("./arsen-sync.controller");
const arsen_sync_guard_1 = require("./arsen-sync.guard");
const arsen_sync_service_1 = require("./arsen-sync.service");
let ArsenSyncModule = class ArsenSyncModule {
};
exports.ArsenSyncModule = ArsenSyncModule;
exports.ArsenSyncModule = ArsenSyncModule = __decorate([
    (0, common_1.Module)({
        controllers: [arsen_sync_controller_1.ArsenSyncController],
        providers: [arsen_sync_guard_1.ArsenSyncGuard, arsen_sync_service_1.ArsenSyncService],
    })
], ArsenSyncModule);
//# sourceMappingURL=arsen-sync.module.js.map