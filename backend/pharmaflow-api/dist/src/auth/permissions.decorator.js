"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Permissions = exports.AUTH_PERMISSIONS_KEY = void 0;
const common_1 = require("@nestjs/common");
exports.AUTH_PERMISSIONS_KEY = 'pharmaflow:auth-permissions';
const Permissions = (...permissions) => (0, common_1.SetMetadata)(exports.AUTH_PERMISSIONS_KEY, permissions);
exports.Permissions = Permissions;
//# sourceMappingURL=permissions.decorator.js.map