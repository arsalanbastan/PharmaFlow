-- CreateTable
CREATE TABLE "bank_accounts" (
    "id" UUID NOT NULL,
    "bankName" TEXT NOT NULL,
    "accountNumber" TEXT,
    "cardNumber" TEXT,
    "shebaNumber" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "bank_accounts_pkey" PRIMARY KEY ("id")
);
