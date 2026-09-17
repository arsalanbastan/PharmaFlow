export const APP_USER_ROLES = ['MANAGER', 'STAFF'] as const;

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
