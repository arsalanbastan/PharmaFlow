-- AlterTable
ALTER TABLE "bank_accounts" ADD COLUMN     "accountHolder" TEXT,
ADD COLUMN     "accountTitle" TEXT;

-- AlterTable
ALTER TABLE "cheques" ADD COLUMN     "dueDate" TIMESTAMP(3),
ADD COLUMN     "imageData" TEXT,
ADD COLUMN     "isRegisteredInSayad" BOOLEAN,
ADD COLUMN     "sayadId" TEXT,
ADD COLUMN     "status" TEXT;

-- AlterTable
ALTER TABLE "companies" ADD COLUMN     "accountantName" TEXT,
ADD COLUMN     "accountantPhone" TEXT,
ADD COLUMN     "visitorName" TEXT,
ADD COLUMN     "visitorPhone" TEXT;

-- CreateIndex
CREATE INDEX "cheques_bankAccountId_chequeNumber_deletedAt_idx" ON "cheques"("bankAccountId", "chequeNumber", "deletedAt");

