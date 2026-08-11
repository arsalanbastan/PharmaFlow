import { existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { randomUUID } from 'node:crypto';

import { NestFactory } from '@nestjs/core';
import { Prisma } from '@prisma/client';
import { open } from 'sqlite';
import sqlite3 from 'sqlite3';

import { AppModule } from '../../app.module';
import { PrismaService } from '../../database/prisma/prisma.service';

type SQLiteCompanyRow = {
  id: string | number;
  name: string;
  national_id: string | null;
  economic_code: string | null;
  notes: string | null;
  visitor_name: string | null;
  visitor_phone: string | null;
  accountant_name: string | null;
  accountant_phone: string | null;
  archived_at: string | number | null;
  created_at: string | number | null;
  updated_at: string | number | null;
};

type SQLiteBankAccountRow = {
  id: string | number;
  bank_name: string;
  account_title: string | null;
  account_holder: string | null;
  account_number: string | null;
  card_number: string | null;
  iban: string | null;
  note: string | null;
  archived_at: string | number | null;
  created_at: string | number | null;
  updated_at: string | number | null;
};

type SQLiteChequeRow = {
  id: string | number;
  bank_account_id: string | number;
  company_id: string | number;
  cheque_number: string;
  amount_rial: string | number;
  issue_date: string | number | null;
  due_date: string | number | null;
  status: string | null;
  is_registered_in_sayad: string | number | null;
  sayad_id: string | null;
  image_data: string | null;
  archived_at: string | number | null;
  created_at: string | number | null;
  updated_at: string | number | null;
};

type ImportCounters = {
  companies: number;
  bankAccounts: number;
  cheques: number;
};

const DEFAULT_SQLITE_PATH =
  'D:/Projects/PharmaFlow/tools/migration/pharmaflow.db';

function parseArgs() {
  const args = process.argv.slice(2);
  return {
    sqlitePath:
      args.find((arg) => arg.startsWith('--sqlite='))?.split('=')[1] ??
      process.env.SQLITE_PATH ??
      DEFAULT_SQLITE_PATH,
    allowNonEmpty: args.includes('--allow-non-empty'),
  };
}

function toDateOrNull(value: string | number | null): Date | null {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  if (typeof value === 'number') {
    const parsedFromNumber = new Date(value);

    if (Number.isNaN(parsedFromNumber.getTime())) {
      throw new Error(`Invalid date value: ${String(value)}`);
    }

    return parsedFromNumber;
  }

  const trimmedValue = value.trim();

  if (!trimmedValue) {
    return null;
  }

  if (/^\d+$/.test(trimmedValue)) {
    const numericValue = Number(trimmedValue);

    if (!Number.isFinite(numericValue)) {
      throw new Error(`Invalid date value: ${value}`);
    }

    const parsedFromTimestamp = new Date(numericValue);

    if (Number.isNaN(parsedFromTimestamp.getTime())) {
      throw new Error(`Invalid date value: ${value}`);
    }

    return parsedFromTimestamp;
  }

  const parsed = new Date(trimmedValue);

  if (Number.isNaN(parsed.getTime())) {
    throw new Error(`Invalid date value: ${value}`);
  }

  return parsed;
}

function toBooleanOrNull(value: string | number | null): boolean | null {
  if (value === null || value === undefined || value === '') {
    return null;
  }

  if (value === 1 || value === '1' || value === 'true') {
    return true;
  }

  if (value === 0 || value === '0' || value === 'false') {
    return false;
  }

  throw new Error(`Invalid boolean-like value: ${String(value)}`);
}

function toDecimalString(value: string | number): string {
  if (value === null || value === undefined || value === '') {
    throw new Error('amount_rial is required');
  }

  const decimal = new Prisma.Decimal(value as Prisma.Decimal.Value);

  return decimal.toFixed();
}

function progress(label: string, current: number, total: number) {
  process.stdout.write(`\r${label}: ${current}/${total}`);

  if (current === total) {
    process.stdout.write('\n');
  }
}

async function runImport() {
  const { sqlitePath, allowNonEmpty } = parseArgs();
  const resolvedSQLitePath = resolve(sqlitePath);

  if (!existsSync(resolvedSQLitePath)) {
    throw new Error(`SQLite file not found: ${resolvedSQLitePath}`);
  }

  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['log', 'error', 'warn'],
  });

  const prisma = app.get(PrismaService);

  const sqliteDb = await open({
    filename: resolvedSQLitePath,
    driver: sqlite3.Database,
  });

  const imported: ImportCounters = {
    companies: 0,
    bankAccounts: 0,
    cheques: 0,
  };

  try {
    console.log('Starting one-time SQLite -> PostgreSQL import');
    console.log(`SQLite path: ${resolvedSQLitePath}`);

    const [sqliteCompaniesCountRow, sqliteBankAccountsCountRow, sqliteChequesCountRow] =
      await Promise.all([
        sqliteDb.get<{ count: number }>(
          'SELECT COUNT(*) as count FROM companies',
        ),
        sqliteDb.get<{ count: number }>(
          'SELECT COUNT(*) as count FROM bank_accounts',
        ),
        sqliteDb.get<{ count: number }>('SELECT COUNT(*) as count FROM cheques'),
      ]);

    const sqliteCompaniesCount = sqliteCompaniesCountRow?.count ?? 0;
    const sqliteBankAccountsCount = sqliteBankAccountsCountRow?.count ?? 0;
    const sqliteChequesCount = sqliteChequesCountRow?.count ?? 0;

    console.log('SQLite counts:');
    console.log(`- companies: ${sqliteCompaniesCount}`);
    console.log(`- bank_accounts: ${sqliteBankAccountsCount}`);
    console.log(`- cheques: ${sqliteChequesCount}`);

    const [pgCompaniesCount, pgBankAccountsCount, pgChequesCount] =
      await Promise.all([
        prisma.company.count(),
        prisma.bankAccount.count(),
        prisma.cheque.count(),
      ]);

    console.log('PostgreSQL counts before import:');
    console.log(`- companies: ${pgCompaniesCount}`);
    console.log(`- bank_accounts: ${pgBankAccountsCount}`);
    console.log(`- cheques: ${pgChequesCount}`);

    const targetHasData =
      pgCompaniesCount > 0 || pgBankAccountsCount > 0 || pgChequesCount > 0;

    if (targetHasData && !allowNonEmpty) {
      throw new Error(
        'Target PostgreSQL tables are not empty. Re-run with --allow-non-empty if you intentionally want to append data.',
      );
    }

    const companies = await sqliteDb.all<SQLiteCompanyRow[]>(
      'SELECT * FROM companies ORDER BY created_at ASC, id ASC',
    );
    const bankAccounts = await sqliteDb.all<SQLiteBankAccountRow[]>(
      'SELECT * FROM bank_accounts ORDER BY created_at ASC, id ASC',
    );
    const cheques = await sqliteDb.all<SQLiteChequeRow[]>(
      'SELECT * FROM cheques ORDER BY created_at ASC, id ASC',
    );

    const companyIdMap = new Map<string, string>();
    const bankAccountIdMap = new Map<string, string>();

    console.log('Importing companies...');

    for (const [index, row] of companies.entries()) {
      if (!row.name?.trim()) {
        throw new Error(`Company row ${String(row.id)} has empty name`);
      }

      const postgresId = randomUUID();
      const createdAt = toDateOrNull(row.created_at) ?? new Date();
      const updatedAt = toDateOrNull(row.updated_at) ?? createdAt;

      await prisma.company.create({
        data: {
          id: postgresId,
          name: row.name.trim(),
          nationalId: row.national_id,
          economicCode: row.economic_code,
          visitorName: row.visitor_name,
          visitorPhone: row.visitor_phone,
          accountantName: row.accountant_name,
          accountantPhone: row.accountant_phone,
          notes: row.notes,
          deletedAt: toDateOrNull(row.archived_at),
          createdAt,
          updatedAt,
        },
      });

      companyIdMap.set(String(row.id), postgresId);
      imported.companies += 1;
      progress('Companies', index + 1, companies.length);
    }

    console.log('Importing bank accounts...');

    for (const [index, row] of bankAccounts.entries()) {
      if (!row.bank_name?.trim()) {
        throw new Error(`Bank account row ${String(row.id)} has empty bank_name`);
      }

      const postgresId = randomUUID();
      const createdAt = toDateOrNull(row.created_at) ?? new Date();
      const updatedAt = toDateOrNull(row.updated_at) ?? createdAt;

      await prisma.bankAccount.create({
        data: {
          id: postgresId,
          bankName: row.bank_name.trim(),
          accountTitle: row.account_title,
          accountHolder: row.account_holder,
          accountNumber: row.account_number,
          cardNumber: row.card_number,
          shebaNumber: row.iban,
          notes: row.note,
          deletedAt: toDateOrNull(row.archived_at),
          createdAt,
          updatedAt,
        },
      });

      bankAccountIdMap.set(String(row.id), postgresId);
      imported.bankAccounts += 1;
      progress('Bank accounts', index + 1, bankAccounts.length);
    }

    console.log('Importing cheques...');

    for (const [index, row] of cheques.entries()) {
      const mappedCompanyId = companyIdMap.get(String(row.company_id));
      const mappedBankAccountId = bankAccountIdMap.get(String(row.bank_account_id));

      if (!mappedCompanyId) {
        throw new Error(
          `Cheque row ${String(row.id)} references missing company_id: ${String(row.company_id)}`,
        );
      }

      if (!mappedBankAccountId) {
        throw new Error(
          `Cheque row ${String(row.id)} references missing bank_account_id: ${String(row.bank_account_id)}`,
        );
      }

      if (!row.cheque_number?.trim()) {
        throw new Error(`Cheque row ${String(row.id)} has empty cheque_number`);
      }

      const chequeDate = toDateOrNull(row.issue_date);

      if (!chequeDate) {
        throw new Error(`Cheque row ${String(row.id)} has null issue_date`);
      }

      const createdAt = toDateOrNull(row.created_at) ?? new Date();
      const updatedAt = toDateOrNull(row.updated_at) ?? createdAt;

      await prisma.cheque.create({
        data: {
          chequeNumber: row.cheque_number.trim(),
          amount: toDecimalString(row.amount_rial),
          chequeDate,
          dueDate: toDateOrNull(row.due_date),
          status: row.status,
          companyId: mappedCompanyId,
          bankAccountId: mappedBankAccountId,
          sayadId: row.sayad_id,
          isRegisteredInSayad: toBooleanOrNull(row.is_registered_in_sayad),
          imageData: row.image_data,
          deletedAt: toDateOrNull(row.archived_at),
          createdAt,
          updatedAt,
        },
      });

      imported.cheques += 1;
      progress('Cheques', index + 1, cheques.length);
    }

    console.log('Import completed successfully.');
    console.log(`Imported companies: ${imported.companies}`);
    console.log(`Imported bank accounts: ${imported.bankAccounts}`);
    console.log(`Imported cheques: ${imported.cheques}`);
  } finally {
    await sqliteDb.close();
    await app.close();
  }
}

runImport().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);

  console.error('Import failed with critical error.');
  console.error(message);
  process.exitCode = 1;
});
