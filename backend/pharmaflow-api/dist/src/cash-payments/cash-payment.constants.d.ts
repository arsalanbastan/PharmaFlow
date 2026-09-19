export declare const CASH_PAYMENT_METHODS: readonly ["BANK_DEPOSIT", "POS_PAYMENT"];
export type CashPaymentMethod = (typeof CASH_PAYMENT_METHODS)[number];
export declare const CASH_PAYMENT_ATTACHMENT_KINDS: readonly ["RECEIPT", "STATEMENT"];
export type CashPaymentAttachmentKind = (typeof CASH_PAYMENT_ATTACHMENT_KINDS)[number];
