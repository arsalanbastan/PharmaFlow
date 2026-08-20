export const CASH_PAYMENT_METHODS = [
  'BANK_DEPOSIT',
  'POS_PAYMENT',
] as const;

export type CashPaymentMethod =
  (typeof CASH_PAYMENT_METHODS)[number];

export const CASH_PAYMENT_ATTACHMENT_KINDS = [
  'RECEIPT',
  'STATEMENT',
] as const;

export type CashPaymentAttachmentKind =
  (typeof CASH_PAYMENT_ATTACHMENT_KINDS)[number];