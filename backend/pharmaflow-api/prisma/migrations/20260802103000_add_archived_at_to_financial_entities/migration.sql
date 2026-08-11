-- AlterTable
ALTER TABLE "companies" ADD COLUMN "archivedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "bank_accounts" ADD COLUMN "archivedAt" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "cheques" ADD COLUMN "archivedAt" TIMESTAMP(3);
