-- CreateTable
CREATE TABLE "cash_payments" (
    "id" UUID NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "paymentDate" TIMESTAMP(3) NOT NULL,
    "companyId" UUID NOT NULL,
    "bankAccountId" UUID NOT NULL,
    "paymentMethod" TEXT NOT NULL,
    "trackingNumber" TEXT,
    "description" TEXT,
    "notes" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "archivedAt" TIMESTAMP(3),
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "cash_payments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cash_payment_attachments" (
    "id" UUID NOT NULL,
    "cashPaymentId" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "fileName" TEXT NOT NULL,
    "mimeType" TEXT NOT NULL,
    "originalFileSize" INTEGER,
    "fileSize" INTEGER NOT NULL,
    "sha256" TEXT NOT NULL,
    "storageKey" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "deletedAt" TIMESTAMP(3),

    CONSTRAINT "cash_payment_attachments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "cash_payments_companyId_paymentDate_idx"
ON "cash_payments"("companyId", "paymentDate");

-- CreateIndex
CREATE INDEX "cash_payments_bankAccountId_paymentDate_idx"
ON "cash_payments"("bankAccountId", "paymentDate");

-- CreateIndex
CREATE INDEX "cash_payments_updatedAt_id_idx"
ON "cash_payments"("updatedAt", "id");

-- CreateIndex
CREATE UNIQUE INDEX "cash_payment_attachments_storageKey_key"
ON "cash_payment_attachments"("storageKey");

-- CreateIndex
CREATE INDEX "cash_payment_attachments_cashPaymentId_kind_deletedAt_idx"
ON "cash_payment_attachments"("cashPaymentId", "kind", "deletedAt");

-- CreateIndex
CREATE INDEX "cash_payment_attachments_updatedAt_id_idx"
ON "cash_payment_attachments"("updatedAt", "id");

-- AddForeignKey
ALTER TABLE "cash_payments"
ADD CONSTRAINT "cash_payments_companyId_fkey"
FOREIGN KEY ("companyId")
REFERENCES "companies"("id")
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_payments"
ADD CONSTRAINT "cash_payments_bankAccountId_fkey"
FOREIGN KEY ("bankAccountId")
REFERENCES "bank_accounts"("id")
ON DELETE RESTRICT
ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_payment_attachments"
ADD CONSTRAINT "cash_payment_attachments_cashPaymentId_fkey"
FOREIGN KEY ("cashPaymentId")
REFERENCES "cash_payments"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;