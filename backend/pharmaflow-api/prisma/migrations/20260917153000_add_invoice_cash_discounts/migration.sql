CREATE TABLE "invoice_discount_allocations" (
  "id" UUID NOT NULL,
  "invoiceId" UUID NOT NULL,
  "amount" DECIMAL(20,4) NOT NULL,
  "description" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "invoice_discount_allocations_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "invoice_discount_allocations_invoiceId_idx"
ON "invoice_discount_allocations"("invoiceId");

ALTER TABLE "invoice_discount_allocations"
ADD CONSTRAINT "invoice_discount_allocations_invoiceId_fkey"
FOREIGN KEY ("invoiceId") REFERENCES "arsen_invoices"("id")
ON DELETE CASCADE ON UPDATE CASCADE;
