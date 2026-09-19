export type PrintCell = string | number | boolean | null | undefined;
export declare function buildPrintToPdfReport(title: string, headers: string[], rows: PrintCell[][], subtitle?: string): string;
