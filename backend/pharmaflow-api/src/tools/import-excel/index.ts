import 'reflect-metadata';

import { resolve } from 'node:path';
import { writeFileSync } from 'node:fs';

import { NestFactory } from '@nestjs/core';
import * as XLSX from 'xlsx';

import { AppModule } from '../../app.module';
import { BankAccountsService } from '../../bank-accounts/bank-accounts.service';
import { CreateBankAccountDto } from '../../bank-accounts/dto/create-bank-account.dto';
import { ChequesService } from '../../cheques/cheques.service';
import { CreateChequeDto } from '../../cheques/dto/create-cheque.dto';
import { CompaniesService } from '../../companies/companies.service';
import { CreateCompanyDto } from '../../companies/dto/create-company.dto';
import { PrismaService } from '../../database/prisma/prisma.service';

type ExcelPrimitive = string | number | boolean | Date | null;

type SheetRow = Record<string, ExcelPrimitive>;

type FailedRow = {
  sheet: 'Companies' | 'BankAccounts' | 'Cheques';
  entity: 'Company' | 'BankAccount' | 'Cheque';
  rowNumber: number;
  reason: string;
};

type ImportSummary = {
  companiesImported: number;
  bankAccountsImported: number;
  chequesImported: number;
  failedCompanies: number;
  failedBankAccounts: number;
  failedCheques: number;
  failedRows: FailedRow[];
  integrity: {
    chequeWithoutCompanyCount: number;
    chequeWithoutBankAccountCount: number;
    sampledChequeCount: number;
    sampledChequeFailures: FailedRow[];
    allImportedEntitiesHaveUuid: boolean;
  };
};

const DEFAULT_EXCEL_PATH = 'D:/import.xlsx';
const SUMMARY_OUTPUT_PATH = 'src/tools/import-excel/last-import-summary.json';
const UUID_REGEX =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function parseArgs() {
  const explicitFile = process.argv
    .slice(2)
    .find((arg) => arg.startsWith('--file='))
    ?.split('=')[1];

  return {
    excelPath: explicitFile ?? process.env.IMPORT_EXCEL_PATH ?? DEFAULT_EXCEL_PATH,
  };
}

function toOptionalString(value: ExcelPrimitive): string | undefined {
  if (value === null || value === undefined) {
    return undefined;
  }

  const stringValue = String(value).trim();
  return stringValue.length > 0 ? stringValue : undefined;
}

function normalizeKey(key: string): string {
  return key
    .replace(/^\uFEFF/, '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
}

function getFieldValue(
  row: SheetRow,
  aliases: string[],
): ExcelPrimitive {
  const normalizedAliasSet = new Set(aliases.map((alias) => normalizeKey(alias)));

  for (const [key, value] of Object.entries(row)) {
    if (normalizedAliasSet.has(normalizeKey(key))) {
      return value;
    }
  }

  return null;
}

function toRequiredString(value: ExcelPrimitive, fieldName: string): string {
  const normalized = toOptionalString(value);

  if (!normalized) {
    throw new Error(`${fieldName} is required`);
  }

  return normalized;
}

function toLegacyKey(value: ExcelPrimitive, fieldName: string): string {
  if (value === null || value === undefined) {
    throw new Error(`${fieldName} is required`);
  }

  return String(value).trim();
}

function toAmountNumber(value: ExcelPrimitive): number {
  if (value === null || value === undefined || value === '') {
    throw new Error('amount_rial is required');
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error('amount_rial is not a finite number');
    }

    return value;
  }

  const normalized = String(value).replace(/,/g, '').trim();
  const parsed = Number(normalized);

  if (!Number.isFinite(parsed)) {
    throw new Error(`amount_rial is invalid: ${String(value)}`);
  }

  return parsed;
}

function toOptionalBoolean(value: ExcelPrimitive): boolean | undefined {
  if (value === null || value === undefined || value === '') {
    return undefined;
  }

  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    if (value === 1) {
      return true;
    }

    if (value === 0) {
      return false;
    }
  }

  const normalized = String(value).trim().toLowerCase();

  if (normalized === '1' || normalized === 'true' || normalized === 'yes') {
    return true;
  }

  if (normalized === '0' || normalized === 'false' || normalized === 'no') {
    return false;
  }

  throw new Error(`is_registered_in_sayad is invalid: ${String(value)}`);
}

function normalizeDateForDto(
  value: ExcelPrimitive,
  fieldName: string,
  isRequired: boolean,
): string | undefined {
  if (value === null || value === undefined || value === '') {
    if (isRequired) {
      throw new Error(`${fieldName} is required`);
    }

    return undefined;
  }

  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) {
      throw new Error(`${fieldName} is invalid date`);
    }

    return value.toISOString();
  }

  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`${fieldName} is invalid date number`);
    }

    return new Date(value).toISOString();
  }

  const normalized = String(value).trim();

  if (!normalized) {
    if (isRequired) {
      throw new Error(`${fieldName} is required`);
    }

    return undefined;
  }

  if (/^\d+$/.test(normalized)) {
    const numericValue = Number(normalized);

    if (!Number.isFinite(numericValue)) {
      throw new Error(`${fieldName} is invalid timestamp`);
    }

    return new Date(numericValue).toISOString();
  }

  const parsed = new Date(normalized);

  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`${fieldName} is invalid date string: ${normalized}`);
  }

  return normalized;
}

function rowToCompanyDto(row: SheetRow): CreateCompanyDto {
  return {
    name: toRequiredString(getFieldValue(row, ['name']), 'name'),
    nationalId: toOptionalString(getFieldValue(row, ['national_id', 'nationalId'])),
    economicCode: toOptionalString(
      getFieldValue(row, ['economic_code', 'economicCode']),
    ),
    notes: toOptionalString(getFieldValue(row, ['notes', 'note'])),
    visitorName: toOptionalString(getFieldValue(row, ['visitor_name', 'visitorName'])),
    visitorPhone: toOptionalString(
      getFieldValue(row, ['visitor_phone', 'visitorPhone']),
    ),
    accountantName: toOptionalString(
      getFieldValue(row, ['accountant_name', 'accountantName']),
    ),
    accountantPhone: toOptionalString(
      getFieldValue(row, ['accountant_phone', 'accountantPhone']),
    ),
  };
}

function rowToBankAccountDto(row: SheetRow): CreateBankAccountDto {
  return {
    bankName: toRequiredString(
      getFieldValue(row, ['bank_name', 'bankName']),
      'bank_name',
    ),
    accountTitle: toOptionalString(
      getFieldValue(row, ['account_title', 'accountTitle']),
    ),
    accountHolder: toOptionalString(
      getFieldValue(row, ['account_holder', 'accountHolder']),
    ),
    accountNumber: toOptionalString(
      getFieldValue(row, ['account_number', 'accountNumber']),
    ),
    cardNumber: toOptionalString(getFieldValue(row, ['card_number', 'cardNumber'])),
    shebaNumber: toOptionalString(getFieldValue(row, ['iban', 'sheba_number', 'shebaNumber'])),
    notes: toOptionalString(getFieldValue(row, ['note', 'notes'])),
  };
}

function rowToChequeDto(
  row: SheetRow,
  companyId: string,
  bankAccountId: string,
): CreateChequeDto {
  return {
    chequeNumber: toRequiredString(
      getFieldValue(row, ['cheque_number', 'chequeNumber']),
      'cheque_number',
    ),
    amount: toAmountNumber(getFieldValue(row, ['amount_rial', 'amount', 'amountRial'])),
    chequeDate: normalizeDateForDto(
      getFieldValue(row, ['issue_date', 'cheque_date', 'chequeDate', 'issueDate']),
      'issue_date',
      true,
    ) as string,
    dueDate: normalizeDateForDto(
      getFieldValue(row, ['due_date', 'dueDate']),
      'due_date',
      false,
    ),
    status: toOptionalString(getFieldValue(row, ['status'])),
    description: toOptionalString(getFieldValue(row, ['description'])),
    isRegisteredInSayad: toOptionalBoolean(
      getFieldValue(row, ['is_registered_in_sayad', 'isRegisteredInSayad']),
    ),
    sayadId: toOptionalString(getFieldValue(row, ['sayad_id', 'sayadId'])),
    imageData: toOptionalString(getFieldValue(row, ['image_data', 'imageData'])),
    companyId,
    bankAccountId,
  };
}

function readSheetRows<T>(
  workbook: XLSX.WorkBook,
  sheetName: string,
): T[] {
  const worksheet = workbook.Sheets[sheetName];

  if (!worksheet) {
    throw new Error(`Required sheet is missing: ${sheetName}`);
  }

  return XLSX.utils.sheet_to_json<T>(worksheet, {
    defval: null,
    raw: true,
  });
}

function shuffleArray<T>(items: T[]): T[] {
  const copy = [...items];

  for (let i = copy.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }

  return copy;
}

async function runImport() {
  const { excelPath } = parseArgs();
  const resolvedPath = resolve(excelPath);

  const workbook = XLSX.readFile(resolvedPath, {
    cellDates: true,
  });

  const companyRows = readSheetRows<SheetRow>(workbook, 'Companies');
  const bankAccountRows = readSheetRows<SheetRow>(
    workbook,
    'BankAccounts',
  );
  const chequeRows = readSheetRows<SheetRow>(workbook, 'Cheques');

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn'],
  });

  const companiesService = app.get(CompaniesService);
  const bankAccountsService = app.get(BankAccountsService);
  const chequesService = app.get(ChequesService);
  const prisma = app.get(PrismaService);

  const legacyCompanyIdToBackendUuid = new Map<string, string>();
  const legacyBankAccountIdToBackendUuid = new Map<string, string>();
  const importedCompanyUuids: string[] = [];
  const importedBankAccountUuids: string[] = [];
  const importedChequeUuids: string[] = [];

  const failedRows: FailedRow[] = [];
  let companiesImported = 0;
  let bankAccountsImported = 0;
  let chequesImported = 0;

  try {
    for (const [index, row] of companyRows.entries()) {
      const rowNumber = index + 2;

      try {
        const legacyId = toLegacyKey(getFieldValue(row, ['id']), 'id');
        const dto = rowToCompanyDto(row);
        const created = await companiesService.create(dto);

        legacyCompanyIdToBackendUuid.set(legacyId, created.id);
        importedCompanyUuids.push(created.id);
        companiesImported += 1;
      } catch (error: unknown) {
        failedRows.push({
          sheet: 'Companies',
          entity: 'Company',
          rowNumber,
          reason: error instanceof Error ? error.message : String(error),
        });
      }
    }

    for (const [index, row] of bankAccountRows.entries()) {
      const rowNumber = index + 2;

      try {
        const legacyId = toLegacyKey(getFieldValue(row, ['id']), 'id');
        const dto = rowToBankAccountDto(row);
        const created = await bankAccountsService.create(dto);

        legacyBankAccountIdToBackendUuid.set(legacyId, created.id);
        importedBankAccountUuids.push(created.id);
        bankAccountsImported += 1;
      } catch (error: unknown) {
        failedRows.push({
          sheet: 'BankAccounts',
          entity: 'BankAccount',
          rowNumber,
          reason: error instanceof Error ? error.message : String(error),
        });
      }
    }

    for (const [index, row] of chequeRows.entries()) {
      const rowNumber = index + 2;

      try {
        const legacyCompanyId = toLegacyKey(
          getFieldValue(row, ['company_id', 'companyId']),
          'company_id',
        );
        const legacyBankAccountId = toLegacyKey(
          getFieldValue(row, ['bank_account_id', 'bankAccountId']),
          'bank_account_id',
        );

        const companyId = legacyCompanyIdToBackendUuid.get(legacyCompanyId);
        const bankAccountId =
          legacyBankAccountIdToBackendUuid.get(legacyBankAccountId);

        if (!companyId) {
          throw new Error(
            `Legacy company id ${legacyCompanyId} was not imported`,
          );
        }

        if (!bankAccountId) {
          throw new Error(
            `Legacy bank account id ${legacyBankAccountId} was not imported`,
          );
        }

        const dto = rowToChequeDto(row, companyId, bankAccountId);
        const created = await chequesService.create(dto);

        importedChequeUuids.push(created.id);
        chequesImported += 1;
      } catch (error: unknown) {
        failedRows.push({
          sheet: 'Cheques',
          entity: 'Cheque',
          rowNumber,
          reason: error instanceof Error ? error.message : String(error),
        });
      }
    }

    const chequesWithRelations = await prisma.cheque.findMany({
      select: {
        id: true,
        companyId: true,
        bankAccountId: true,
        company: {
          select: {
            id: true,
          },
        },
        bankAccount: {
          select: {
            id: true,
          },
        },
      },
    });

    const chequeWithoutCompanyCount = chequesWithRelations.filter(
      (item) => !item.company,
    ).length;
    const chequeWithoutBankAccountCount = chequesWithRelations.filter(
      (item) => !item.bankAccount,
    ).length;

    const randomSample = shuffleArray(chequesWithRelations).slice(
      0,
      Math.min(20, chequesWithRelations.length),
    );

    const sampledChequeFailures: FailedRow[] = [];

    randomSample.forEach((item, index) => {
      const rowNumber = index + 1;

      if (!item.company) {
        sampledChequeFailures.push({
          sheet: 'Cheques',
          entity: 'Cheque',
          rowNumber,
          reason: `Cheque ${item.id} has no linked company`,
        });
      }

      if (!item.bankAccount) {
        sampledChequeFailures.push({
          sheet: 'Cheques',
          entity: 'Cheque',
          rowNumber,
          reason: `Cheque ${item.id} has no linked bank account`,
        });
      }

      if (!UUID_REGEX.test(item.id)) {
        sampledChequeFailures.push({
          sheet: 'Cheques',
          entity: 'Cheque',
          rowNumber,
          reason: `Cheque ${item.id} is not a UUID`,
        });
      }

      if (!UUID_REGEX.test(item.companyId)) {
        sampledChequeFailures.push({
          sheet: 'Cheques',
          entity: 'Cheque',
          rowNumber,
          reason: `CompanyId ${item.companyId} is not a UUID`,
        });
      }

      if (!UUID_REGEX.test(item.bankAccountId)) {
        sampledChequeFailures.push({
          sheet: 'Cheques',
          entity: 'Cheque',
          rowNumber,
          reason: `BankAccountId ${item.bankAccountId} is not a UUID`,
        });
      }
    });

    const allImportedEntitiesHaveUuid =
      importedCompanyUuids.every((id) => UUID_REGEX.test(id)) &&
      importedBankAccountUuids.every((id) => UUID_REGEX.test(id)) &&
      importedChequeUuids.every((id) => UUID_REGEX.test(id));

    const summary: ImportSummary = {
      companiesImported,
      bankAccountsImported,
      chequesImported,
      failedCompanies: failedRows.filter((item) => item.entity === 'Company').length,
      failedBankAccounts: failedRows.filter((item) => item.entity === 'BankAccount')
        .length,
      failedCheques: failedRows.filter((item) => item.entity === 'Cheque').length,
      failedRows,
      integrity: {
        chequeWithoutCompanyCount,
        chequeWithoutBankAccountCount,
        sampledChequeCount: randomSample.length,
        sampledChequeFailures,
        allImportedEntitiesHaveUuid,
      },
    };

    writeFileSync(SUMMARY_OUTPUT_PATH, `${JSON.stringify(summary, null, 2)}\n`, {
      encoding: 'utf8',
    });

    const compactSummary = {
      companiesImported: summary.companiesImported,
      bankAccountsImported: summary.bankAccountsImported,
      chequesImported: summary.chequesImported,
      failedCompanies: summary.failedCompanies,
      failedBankAccounts: summary.failedBankAccounts,
      failedCheques: summary.failedCheques,
      failedRowsCount: summary.failedRows.length,
      integrity: summary.integrity,
    };

    console.log(JSON.stringify(compactSummary, null, 2));
    console.log(`Summary file: ${SUMMARY_OUTPUT_PATH}`);
  } finally {
    await app.close();
  }
}

runImport().catch((error: unknown) => {
  const reason = error instanceof Error ? error.message : String(error);

  console.error('Import script failed with fatal error.');
  console.error(reason);
  process.exitCode = 1;
});
