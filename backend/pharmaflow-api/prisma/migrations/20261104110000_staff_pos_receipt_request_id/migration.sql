-- Prevent attaching a successful POS payment request to more than one invoice.
ALTER TABLE "sales_invoices" ADD COLUMN "posPaymentRequestId" TEXT;
CREATE UNIQUE INDEX "sales_invoices_posPaymentRequestId_key"
  ON "sales_invoices"("posPaymentRequestId");
