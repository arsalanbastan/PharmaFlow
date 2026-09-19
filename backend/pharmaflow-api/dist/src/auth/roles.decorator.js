"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Roles = exports.AUTH_ROLES_KEY = void 0;
const common_1 = require("@nestjs/common");
exports.AUTH_ROLES_KEY = 'pharmaflow-auth-roles';
const Roles = (...roles) => (0, common_1.SetMetadata)(exports.AUTH_ROLES_KEY, roles);
exports.Roles = Roles;
//# sourceMappingURL=roles.decorator.js.map