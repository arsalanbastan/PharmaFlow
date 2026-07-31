-- CreateTable
CREATE TABLE "cheques" (
    "id" UUID NOT NULL,
    "chequeNumber" TEXT NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "chequeDate" TIMESTAMP(3) NOT NULL,
    "companyId" UUID NOT NULL,
    "bankAccountId" UUID NOT NULL,
    "sayadStatus" TEXT,
    "imagePath" TEXT,
    "description" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "cheques_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "cheques" ADD CONSTRAINT "cheques_companyId_fkey" FOREIGN KEY ("companyId") REFERENCES "companies"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cheques" ADD CONSTRAINT "cheques_bankAccountId_fkey" FOREIGN KEY ("bankAccountId") REFERENCES "bank_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
