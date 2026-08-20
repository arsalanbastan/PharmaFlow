export const CHEQUE_ATTACHMENT_KINDS = ['STATEMENT'] as const;

export type ChequeAttachmentKind = (typeof CHEQUE_ATTACHMENT_KINDS)[number];
