export declare const ADMIN_DASHBOARD_RELEASE = "invoice-multi-settlement-v9-20260917";
export declare function invoicePaginationWindow(currentPage: number, totalPages: number, maxVisible?: number): {
    pages: number[];
    showLeadingEllipsis: boolean;
    showTrailingEllipsis: boolean;
};
export declare function escapeHtml(value: unknown): string;
export declare function formatAmount(value: unknown): string;
export declare function formatDate(value: Date | string | null | undefined): string;
export declare function inputDate(value: Date | string | null | undefined): string;
export declare function inputDateTime(value: Date | string | null | undefined): string;
export declare function statusBadge(value: unknown): string;
export declare function notice(text: string | undefined, danger?: boolean): string;
export declare function hardDeleteForm(action: string, csrfToken: string, label: string, disabledReason?: string): string;
export declare function layout(title: string, body: string, active?: string): string;
