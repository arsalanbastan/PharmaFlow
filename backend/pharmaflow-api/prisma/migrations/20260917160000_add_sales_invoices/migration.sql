CREATE TABLE "sales_invoice_profiles" (
  "id" TEXT NOT NULL DEFAULT 'default',
  "sellerName" TEXT NOT NULL DEFAULT 'داروخانه دکتر خسروانی',
  "legalName" TEXT,
  "nationalId" TEXT,
  "economicCode" TEXT,
  "phone" TEXT,
  "address" TEXT,
  "logoData" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "sales_invoice_profiles_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "sales_invoices" (
  "id" UUID NOT NULL,
  "sequence" BIGSERIAL NOT NULL,
  "invoiceNumber" TEXT,
  "issueDate" TIMESTAMP(3) NOT NULL,
  "buyerName" TEXT NOT NULL,
  "buyerNationalId" TEXT,
  "buyerPhone" TEXT,
  "buyerAddress" TEXT,
  "sellerName" TEXT NOT NULL,
  "sellerLegalName" TEXT,
  "sellerNationalId" TEXT,
  "sellerEconomicCode" TEXT,
  "sellerPhone" TEXT,
  "sellerAddress" TEXT,
  "sellerLogoData" TEXT,
  "subtotal" DECIMAL(20,4) NOT NULL,
  "discount" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "payableAmount" DECIMAL(20,4) NOT NULL,
  "notes" TEXT,
  "status" TEXT NOT NULL DEFAULT 'ISSUED',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "sales_invoices_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "sales_invoice_items" (
  "id" UUID NOT NULL,
  "invoiceId" UUID NOT NULL,
  "catalogItemId" UUID,
  "arsenDrugId" BIGINT,
  "itemName" TEXT NOT NULL,
  "barcode" TEXT,
  "unit" TEXT,
  "quantity" DECIMAL(20,4) NOT NULL,
  "unitPrice" DECIMAL(20,4) NOT NULL,
  "lineDiscount" DECIMAL(20,4) NOT NULL DEFAULT 0,
  "lineTotal" DECIMAL(20,4) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "sales_invoice_items_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "sales_invoices_sequence_key" ON "sales_invoices"("sequence");
CREATE UNIQUE INDEX "sales_invoices_invoiceNumber_key" ON "sales_invoices"("invoiceNumber");
CREATE INDEX "sales_invoices_issueDate_sequence_idx" ON "sales_invoices"("issueDate" DESC, "sequence" DESC);
CREATE INDEX "sales_invoices_buyerName_idx" ON "sales_invoices"("buyerName");
CREATE INDEX "sales_invoice_items_invoiceId_idx" ON "sales_invoice_items"("invoiceId");
CREATE INDEX "sales_invoice_items_catalogItemId_idx" ON "sales_invoice_items"("catalogItemId");

ALTER TABLE "sales_invoice_items"
ADD CONSTRAINT "sales_invoice_items_invoiceId_fkey"
FOREIGN KEY ("invoiceId") REFERENCES "sales_invoices"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
