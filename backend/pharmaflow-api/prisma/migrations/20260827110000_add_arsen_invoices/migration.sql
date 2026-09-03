CREATE TABLE "arsen_invoices" (
    "id" UUID NOT NULL,
    "ingestSequence" BIGSERIAL NOT NULL,
    "arsenFactorId" INTEGER NOT NULL,
    "invoiceNumber" TEXT,
    "invoiceDate" TEXT,
    "docDate" TEXT,
    "factorDocType" INTEGER NOT NULL,
    "factorDocTypeName" TEXT,
    "factorType" INTEGER,
    "factorTypeName" TEXT,
    "factorItemType" TEXT,
    "arsenBusinessPartnerId" INTEGER NOT NULL,
    "arsenBusinessPartnerName" TEXT NOT NULL,
    "companyId" UUID NOT NULL,
    "factorTotalPrice" DECIMAL(20,4),
    "factorDiscount" DECIMAL(20,4),
    "factorTax" DECIMAL(20,4),
    "factorPayablePrice" DECIMAL(20,4),
    "barbariPrice" DECIMAL(20,4),
    "paymentDays" INTEGER,
    "isDeletedInArsen" BOOLEAN NOT NULL DEFAULT false,
    "isLockedInArsen" BOOLEAN,
    "arsenSaveDateTime" TIMESTAMP(3),
    "itemCount" INTEGER NOT NULL DEFAULT 0,
    "importedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "sourceSyncedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "arsen_invoices_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "arsen_invoice_items" (
    "id" UUID NOT NULL,
    "invoiceId" UUID NOT NULL,
    "arsenFactorDetailId" BIGINT NOT NULL,
    "arsenFactorDetailsId" INTEGER,
    "arsenDrugId" BIGINT,
    "drugName" TEXT,
    "barcode" TEXT,
    "packetQuantity" INTEGER,
    "quantity" DOUBLE PRECISION,
    "salePrice" DECIMAL(20,4),
    "purchasePrice" DECIMAL(20,4),
    "rowDiscount" DECIMAL(20,4),
    "hasTax" INTEGER,
    "expireDate" TEXT,
    "expireDateGregorian" TIMESTAMP(3),
    "batchNumber" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "arsen_invoice_items_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "arsen_invoices_ingestSequence_key"
ON "arsen_invoices"("ingestSequence");

CREATE UNIQUE INDEX "arsen_invoices_arsenFactorId_key"
ON "arsen_invoices"("arsenFactorId");

CREATE INDEX "arsen_invoices_companyId_ingestSequence_idx"
ON "arsen_invoices"("companyId", "ingestSequence" DESC);

CREATE INDEX "arsen_invoices_factorDocType_ingestSequence_idx"
ON "arsen_invoices"("factorDocType", "ingestSequence" DESC);

CREATE INDEX "arsen_invoices_invoiceDate_ingestSequence_idx"
ON "arsen_invoices"("invoiceDate", "ingestSequence" DESC);

CREATE INDEX "arsen_invoices_invoiceNumber_idx"
ON "arsen_invoices"("invoiceNumber");

CREATE UNIQUE INDEX "arsen_invoice_items_arsenFactorDetailId_key"
ON "arsen_invoice_items"("arsenFactorDetailId");

CREATE INDEX "arsen_invoice_items_invoiceId_arsenFactorDetailsId_idx"
ON "arsen_invoice_items"("invoiceId", "arsenFactorDetailsId");

CREATE INDEX "arsen_invoice_items_arsenDrugId_idx"
ON "arsen_invoice_items"("arsenDrugId");

ALTER TABLE "arsen_invoices"
ADD CONSTRAINT "arsen_invoices_companyId_fkey"
FOREIGN KEY ("companyId") REFERENCES "companies"("id")
ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "arsen_invoice_items"
ADD CONSTRAINT "arsen_invoice_items_invoiceId_fkey"
FOREIGN KEY ("invoiceId") REFERENCES "arsen_invoices"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
