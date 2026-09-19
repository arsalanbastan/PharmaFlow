export declare class CreateAppUserDto {
    username: string;
    displayName: string;
    password: string;
    role: 'MANAGER' | 'STAFF';
    managerAppAccess?: boolean;
    canCreateOrders?: boolean;
    canCreateCheques?: boolean;
    canCreateCashPayments?: boolean;
    canViewFinancialReports?: boolean;
}
