CREATE TABLE "cheque_invoice_allocations" (
    "id" UUID NOT NULL,
    "invoiceId" UUID NOT NULL,
    "chequeId" UUID NOT NULL,
    "amount" DECIMAL(20,4) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "cheque_invoice_allocations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "cheque_invoice_allocations_amount_check" CHECK ("amount" > 0)
);

CREATE TABLE "cash_payment_invoice_allocations" (
    "id" UUID NOT NULL,
    "invoiceId" UUID NOT NULL,
    "cashPaymentId" UUID NOT NULL,
    "amount" DECIMAL(20,4) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "cash_payment_invoice_allocations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "cash_payment_invoice_allocations_amount_check" CHECK ("amount" > 0)
);

CREATE UNIQUE INDEX "cheque_invoice_allocations_invoiceId_chequeId_key" ON "cheque_invoice_allocations"("invoiceId", "chequeId");
CREATE INDEX "cheque_invoice_allocations_chequeId_idx" ON "cheque_invoice_allocations"("chequeId");
CREATE UNIQUE INDEX "cash_payment_invoice_allocations_invoiceId_cashPaymentId_key" ON "cash_payment_invoice_allocations"("invoiceId", "cashPaymentId");
CREATE INDEX "cash_payment_invoice_allocations_cashPaymentId_idx" ON "cash_payment_invoice_allocations"("cashPaymentId");

ALTER TABLE "cheque_invoice_allocations" ADD CONSTRAINT "cheque_invoice_allocations_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "arsen_invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "cheque_invoice_allocations" ADD CONSTRAINT "cheque_invoice_allocations_chequeId_fkey" FOREIGN KEY ("chequeId") REFERENCES "cheques"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "cash_payment_invoice_allocations" ADD CONSTRAINT "cash_payment_invoice_allocations_invoiceId_fkey" FOREIGN KEY ("invoiceId") REFERENCES "arsen_invoices"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "cash_payment_invoice_allocations" ADD CONSTRAINT "cash_payment_invoice_allocations_cashPaymentId_fkey" FOREIGN KEY ("cashPaymentId") REFERENCES "cash_payments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
