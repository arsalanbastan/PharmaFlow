export type ExcelCell = string | number | boolean | null | undefined;
export declare function buildXlsx(sheetName: string, headers: string[], rows: ExcelCell[][]): Buffer;
