"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChequesModule = void 0;
const common_1 = require("@nestjs/common");
const auth_module_1 = require("../auth/auth.module");
const cheque_attachment_storage_service_1 = require("./cheque-attachment-storage.service");
const cheque_attachments_controller_1 = require("./cheque-attachments.controller");
const cheque_attachments_service_1 = require("./cheque-attachments.service");
const cheques_controller_1 = require("./cheques.controller");
const cheques_service_1 = require("./cheques.service");
let ChequesModule = class ChequesModule {
};
exports.ChequesModule = ChequesModule;
exports.ChequesModule = ChequesModule = __decorate([
    (0, common_1.Module)({
        imports: [auth_module_1.AuthModule],
        controllers: [cheques_controller_1.ChequesController, cheque_attachments_controller_1.ChequeAttachmentsController],
        providers: [
            cheques_service_1.ChequesService,
            cheque_attachments_service_1.ChequeAttachmentsService,
            cheque_attachment_storage_service_1.ChequeAttachmentStorageService,
        ],
        exports: [cheques_service_1.ChequesService, cheque_attachments_service_1.ChequeAttachmentsService],
    })
], ChequesModule);
//# sourceMappingURL=cheques.module.js.map