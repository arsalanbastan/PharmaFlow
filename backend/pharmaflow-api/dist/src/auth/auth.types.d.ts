export declare const APP_USER_ROLES: readonly ["MANAGER", "STAFF"];
export type AppUserRole = (typeof APP_USER_ROLES)[number];
export type AppUserPermissions = {
    managerAppAccess: boolean;
    canCreateOrders: boolean;
    canCreateCheques: boolean;
    canCreateCashPayments: boolean;
    canViewFinancialReports: boolean;
};
export type AuthPrincipal = {
    userId: string;
    username: string;
    displayName: string;
    role: AppUserRole;
    permissions: AppUserPermissions;
};
export type PublicAppUser = AuthPrincipal & {
    isActive: boolean;
};
