ALTER TABLE "app_users"
ADD COLUMN "managerAppAccess" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canCreateOrders" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN "canCreateCheques" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canCreateCashPayments" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN "canViewFinancialReports" BOOLEAN NOT NULL DEFAULT false;

UPDATE "app_users"
SET
  "managerAppAccess" = true,
  "canCreateOrders" = true,
  "canCreateCheques" = true,
  "canCreateCashPayments" = true,
  "canViewFinancialReports" = true
WHERE "role" = 'MANAGER';