ALTER TABLE "sales_invoice_profiles"
ADD COLUMN "manualServiceTariff" DECIMAL(20,4) NOT NULL DEFAULT 81000,
ADD COLUMN "freeServiceTariff" DECIMAL(20,4) NOT NULL DEFAULT 727000;

ALTER TABLE "sales_invoices"
ADD COLUMN "invoiceType" TEXT NOT NULL DEFAULT 'LEGACY',
ADD COLUMN "serviceTariff" DECIMAL(20,4) NOT NULL DEFAULT 0;

CREATE INDEX "arsen_invoice_items_barcode_idx" ON "arsen_invoice_items"("barcode");
