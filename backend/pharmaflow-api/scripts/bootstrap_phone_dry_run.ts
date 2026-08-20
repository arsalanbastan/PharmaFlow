import { readFileSync } from 'node:fs';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const EXPORT_PATH =
  'D:\\PharmaFlowBootstrap\\phone_bootstrap_export.json';

type JsonRow = Record<string, unknown>;

interface PhoneExport {
  format: string;
  companies: JsonRow[];
  bankAccounts: JsonRow[];
  cheques: JsonRow[];
  syncQueue: JsonRow[];
}

function nullableString(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const trimmed = value.trim();

  return trimmed.length === 0 ? null : trimmed;
}

function localUuidSet(
  rows: JsonRow[],
): Set<string> {
  return new Set(
    rows
      .map((row) => nullableString(row.server_uuid))
      .filter((value): value is string => value !== null),
  );
}

function duplicateUuids(
  rows: JsonRow[],
): string[] {
  const counts = new Map<string, number>();

  for (const row of rows) {
    const uuid = nullableString(row.server_uuid);

    if (!uuid) {
      continue;
    }

    counts.set(
      uuid,
      (counts.get(uuid) ?? 0) + 1,
    );
  }

  return [...counts.entries()]
    .filter(([, count]) => count > 1)
    .map(([uuid]) => uuid);
}

function serverOnlyIds(
  ids: string[],
  localIds: Set<string>,
): string[] {
  return ids.filter((id) => !localIds.has(id));
}

async function main() {
  const raw = readFileSync(
    EXPORT_PATH,
    'utf8',
  );

  const phone = JSON.parse(raw) as PhoneExport;

  if (
    phone.format !==
    'pharmaflow-phone-bootstrap-v1'
  ) {
    throw new Error(
      `Unexpected export format: ${phone.format}`,
    );
  }

  const [
    serverCompanies,
    serverBankAccounts,
    serverCheques,
  ] = await Promise.all([
    prisma.company.findMany(),
    prisma.bankAccount.findMany(),
    prisma.cheque.findMany(),
  ]);

  const companyUuids =
    localUuidSet(phone.companies);

  const bankUuids =
    localUuidSet(phone.bankAccounts);

  const chequeUuids =
    localUuidSet(phone.cheques);

  const duplicateCompanyUuids =
    duplicateUuids(phone.companies);

  const duplicateBankUuids =
    duplicateUuids(phone.bankAccounts);

  const duplicateChequeUuids =
    duplicateUuids(phone.cheques);

  const companiesWithoutUuid =
    phone.companies.filter(
      (row) => !nullableString(row.server_uuid),
    );

  const banksWithoutUuid =
    phone.bankAccounts.filter(
      (row) => !nullableString(row.server_uuid),
    );

  const chequesWithoutUuid =
    phone.cheques.filter(
      (row) => !nullableString(row.server_uuid),
    );

  const localCompanyIds = new Set(
    phone.companies.map(
      (row) => Number(row.id),
    ),
  );

  const localBankIds = new Set(
    phone.bankAccounts.map(
      (row) => Number(row.id),
    ),
  );

  const brokenCompanyRefs =
    phone.cheques.filter(
      (row) =>
        !localCompanyIds.has(
          Number(row.company_id),
        ),
    );

  const brokenBankRefs =
    phone.cheques.filter(
      (row) =>
        !localBankIds.has(
          Number(row.bank_account_id),
        ),
    );

  const deletedPhoneCheques =
    phone.cheques.filter(
      (row) =>
        row.delete_requested_at !== null &&
        row.delete_requested_at !== undefined,
    );

  const archivedPhoneCheques =
    phone.cheques.filter(
      (row) =>
        row.archived_at !== null &&
        row.archived_at !== undefined,
    );

  const pendingQueue =
    phone.syncQueue.filter(
      (row) =>
        String(row.status).toUpperCase() ===
        'PENDING',
    );

  const serverOnlyCompanies =
    serverOnlyIds(
      serverCompanies.map((row) => row.id),
      companyUuids,
    );

  const serverOnlyBanks =
    serverOnlyIds(
      serverBankAccounts.map((row) => row.id),
      bankUuids,
    );

  const serverOnlyCheques =
    serverOnlyIds(
      serverCheques.map((row) => row.id),
      chequeUuids,
    );

  const activeServerOnlyCompanies =
    serverCompanies.filter(
      (row) =>
        serverOnlyCompanies.includes(row.id) &&
        row.deletedAt === null,
    );

  const deletedServerOnlyCompanies =
    serverCompanies.filter(
      (row) =>
        serverOnlyCompanies.includes(row.id) &&
        row.deletedAt !== null,
    );

  const activeServerOnlyBanks =
    serverBankAccounts.filter(
      (row) =>
        serverOnlyBanks.includes(row.id) &&
        row.deletedAt === null,
    );

  const deletedServerOnlyBanks =
    serverBankAccounts.filter(
      (row) =>
        serverOnlyBanks.includes(row.id) &&
        row.deletedAt !== null,
    );

  const activeServerOnlyCheques =
    serverCheques.filter(
      (row) =>
        serverOnlyCheques.includes(row.id) &&
        row.deletedAt === null,
    );

  const deletedServerOnlyCheques =
    serverCheques.filter(
      (row) =>
        serverOnlyCheques.includes(row.id) &&
        row.deletedAt !== null,
    );

  const companyNameConflicts: Array<{
    phoneLocalId: unknown;
    phoneUuid: string | null;
    name: string;
    serverUuid: string;
    serverDeleted: boolean;
  }> = [];

  for (const company of phone.companies) {
    const name =
      nullableString(company.name);

    if (!name) {
      continue;
    }

    const localUuid =
      nullableString(company.server_uuid);

    const conflicting =
      serverCompanies.find(
        (server) =>
          server.name === name &&
          server.id !== localUuid,
      );

    if (conflicting) {
      companyNameConflicts.push({
        phoneLocalId: company.id,
        phoneUuid: localUuid,
        name,
        serverUuid: conflicting.id,
        serverDeleted:
          conflicting.deletedAt !== null,
      });
    }
  }

  const blockers: string[] = [];
  const warnings: string[] = [];

  if (duplicateCompanyUuids.length > 0) {
    blockers.push(
      `Duplicate Company UUIDs: ${duplicateCompanyUuids.length}`,
    );
  }

  if (duplicateBankUuids.length > 0) {
    blockers.push(
      `Duplicate BankAccount UUIDs: ${duplicateBankUuids.length}`,
    );
  }

  if (duplicateChequeUuids.length > 0) {
    blockers.push(
      `Duplicate Cheque UUIDs: ${duplicateChequeUuids.length}`,
    );
  }

  if (brokenCompanyRefs.length > 0) {
    blockers.push(
      `Cheques with missing Company: ${brokenCompanyRefs.length}`,
    );
  }

  if (brokenBankRefs.length > 0) {
    blockers.push(
      `Cheques with missing BankAccount: ${brokenBankRefs.length}`,
    );
  }

  if (companyNameConflicts.length > 0) {
    blockers.push(
      `Company unique-name conflicts: ${companyNameConflicts.length}`,
    );
  }

  if (activeServerOnlyCompanies.length > 0) {
    blockers.push(
      `Active server-only Companies: ${activeServerOnlyCompanies.length}`,
    );
  }

  if (activeServerOnlyBanks.length > 0) {
    blockers.push(
      `Active server-only BankAccounts: ${activeServerOnlyBanks.length}`,
    );
  }

  if (activeServerOnlyCheques.length > 0) {
    blockers.push(
      `Active server-only Cheques: ${activeServerOnlyCheques.length}`,
    );
  }

  if (deletedServerOnlyCompanies.length > 0) {
    warnings.push(
      `Soft-deleted server-only Companies: ${deletedServerOnlyCompanies.length}`,
    );
  }

  if (deletedServerOnlyBanks.length > 0) {
    warnings.push(
      `Soft-deleted server-only BankAccounts: ${deletedServerOnlyBanks.length}`,
    );
  }

  if (deletedServerOnlyCheques.length > 0) {
    warnings.push(
      `Soft-deleted server-only Cheques: ${deletedServerOnlyCheques.length}`,
    );
  }

  console.log('');
  console.log(
    '========================================',
  );
  console.log(
    'PHARMAFLOW BOOTSTRAP DRY RUN',
  );
  console.log(
    '========================================',
  );

  console.log('');
  console.log('PHONE:');
  console.log(
    `  Companies: ${phone.companies.length}`,
  );
  console.log(
    `    with UUID: ${companyUuids.size}`,
  );
  console.log(
    `    without UUID: ${companiesWithoutUuid.length}`,
  );

  console.log(
    `  BankAccounts: ${phone.bankAccounts.length}`,
  );
  console.log(
    `    with UUID: ${bankUuids.size}`,
  );
  console.log(
    `    without UUID: ${banksWithoutUuid.length}`,
  );

  console.log(
    `  Cheques: ${phone.cheques.length}`,
  );
  console.log(
    `    with UUID: ${chequeUuids.size}`,
  );
  console.log(
    `    without UUID: ${chequesWithoutUuid.length}`,
  );
  console.log(
    `    archived: ${archivedPhoneCheques.length}`,
  );
  console.log(
    `    delete requested: ${deletedPhoneCheques.length}`,
  );

  console.log(
    `  Pending queue items: ${pendingQueue.length}`,
  );

  console.log('');
  console.log('SERVER:');
  console.log(
    `  Companies total: ${serverCompanies.length}`,
  );
  console.log(
    `  BankAccounts total: ${serverBankAccounts.length}`,
  );
  console.log(
    `  Cheques total: ${serverCheques.length}`,
  );

  console.log('');
  console.log('SERVER-ONLY:');
  console.log(
    `  Active Companies: ${activeServerOnlyCompanies.length}`,
  );
  console.log(
    `  Deleted Companies: ${deletedServerOnlyCompanies.length}`,
  );
  console.log(
    `  Active BankAccounts: ${activeServerOnlyBanks.length}`,
  );
  console.log(
    `  Deleted BankAccounts: ${deletedServerOnlyBanks.length}`,
  );
  console.log(
    `  Active Cheques: ${activeServerOnlyCheques.length}`,
  );
  console.log(
    `  Deleted Cheques: ${deletedServerOnlyCheques.length}`,
  );

  console.log('');
  console.log('MISSING UUID ROWS:');

  for (const row of companiesWithoutUuid) {
    console.log(
      `  COMPANY localId=${row.id} name=${row.name}`,
    );
  }

  for (const row of chequesWithoutUuid) {
    console.log(
      `  CHEQUE localId=${row.id} number=${row.cheque_number}`,
    );
  }

  console.log('');
  console.log('PENDING QUEUE:');

  for (const row of pendingQueue) {
    console.log(
      `  ${row.entityType} ` +
        `entityId=${row.entityId} ` +
        `operation=${row.operation}`,
    );
  }

  if (companyNameConflicts.length > 0) {
    console.log('');
    console.log(
      'COMPANY NAME CONFLICTS:',
    );

    for (const conflict of companyNameConflicts) {
      console.log(
        `  ${conflict.name} ` +
          `phoneLocalId=${conflict.phoneLocalId} ` +
          `phoneUuid=${conflict.phoneUuid} ` +
          `serverUuid=${conflict.serverUuid} ` +
          `serverDeleted=${conflict.serverDeleted}`,
      );
    }
  }

  console.log('');
  console.log('WARNINGS:');

  if (warnings.length === 0) {
    console.log('  none');
  } else {
    for (const warning of warnings) {
      console.log(`  - ${warning}`);
    }
  }

  console.log('');
  console.log('BLOCKERS:');

  if (blockers.length === 0) {
    console.log('  none');
  } else {
    for (const blocker of blockers) {
      console.log(`  - ${blocker}`);
    }
  }

  console.log('');
  console.log(
    `SAFE TO PREPARE IMPORT: ${
      blockers.length === 0 ? 'YES' : 'NO'
    }`,
  );

  console.log('');
  console.log(
    'NO DATA WAS MODIFIED.',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });