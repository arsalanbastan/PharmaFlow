-- Staff Web shared POS configuration.
CREATE TABLE "staff_web_settings" (
    "id" TEXT NOT NULL DEFAULT 'default',
    "posBridgeHost" TEXT,
    "posBridgePort" INTEGER NOT NULL DEFAULT 17905,
    "posDevices" JSONB NOT NULL DEFAULT '[]',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    CONSTRAINT "staff_web_settings_pkey" PRIMARY KEY ("id")
);

-- Optional successful POS payment metadata captured with a sales invoice.
ALTER TABLE "sales_invoices"
ADD COLUMN "posPaymentStatus" TEXT,
ADD COLUMN "posPaymentDeviceId" TEXT,
ADD COLUMN "posPaymentDeviceName" TEXT,
ADD COLUMN "posPaymentTerminalId" TEXT,
ADD COLUMN "posPaymentTraceNumber" TEXT,
ADD COLUMN "posPaymentRrn" TEXT,
ADD COLUMN "posPaymentResponseCode" TEXT,
ADD COLUMN "posPaymentResponseDescription" TEXT,
ADD COLUMN "posPaymentPaidAmount" DECIMAL(20,4),
ADD COLUMN "posPaymentAt" TIMESTAMP(3);
