import { randomUUID } from 'node:crypto';
import {
  existsSync,
  readFileSync,
  writeFileSync,
} from 'node:fs';

import {
  Prisma,
  PrismaClient,
} from '@prisma/client';

const prisma = new PrismaClient();

const EXPORT_PATH =
  'D:\\PharmaFlowBootstrap\\phone_bootstrap_export.json';

const ASSIGNMENTS_PATH =
  'D:\\PharmaFlowBootstrap\\phone_uuid_assignments.json';

const SERVER_BACKUP_PATH =
  'D:\\PharmaFlowBootstrap\\server_before_phone_import.json';

type JsonRow = Record<string, unknown>;

interface PhoneExport {
  format: string;
  companies: JsonRow[];
  bankAccounts: JsonRow[];
  cheques: JsonRow[];
  syncQueue: JsonRow[];
}

interface UuidAssignment {
  localId: number;
  uuid: string;
}

interface AssignmentFile {
  format: string;
  company: UuidAssignment[];
  cheques: UuidAssignment[];
}

function requiredInt(
  value: unknown,
  field: string,
): number {
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(
        `Invalid number for ${field}: ${value}`,
      );
    }

    return Math.trunc(value);
  }

  if (typeof value === 'string') {
    const parsed = Number(value);

    if (Number.isFinite(parsed)) {
      return Math.trunc(parsed);
    }
  }

  throw new Error(
    `Expected integer-compatible value for ${field}`,
  );
}

function requiredString(
  value: unknown,
  field: string,
): string {
  if (typeof value !== 'string') {
    throw new Error(
      `Expected string for ${field}`,
    );
  }

  return value;
}

function nullableString(
  value: unknown,
): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value !== 'string') {
    return String(value);
  }

  const trimmed = value.trim();

  return trimmed.length === 0
    ? null
    : trimmed;
}

function requiredDate(
  value: unknown,
  field: string,
): Date {
  const milliseconds =
    requiredInt(value, field);

  const date = new Date(milliseconds);

  if (Number.isNaN(date.getTime())) {
    throw new Error(
      `Invalid date for ${field}: ${value}`,
    );
  }

  return date;
}

function nullableDate(
  value: unknown,
  field: string,
): Date | null {
  if (value === null || value === undefined) {
    return null;
  }

  return requiredDate(value, field);
}

function booleanFromFlag(
  value: unknown,
): boolean {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  if (typeof value === 'string') {
    const normalized =
      value.trim().toLowerCase();

    return (
      normalized === '1' ||
      normalized === 'true'
    );
  }

  return false;
}

function imageDataFromExport(
  value: unknown,
): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === 'string') {
    return value;
  }

  if (
    typeof value === 'object' &&
    value !== null
  ) {
    const object =
      value as Record<string, unknown>;

    if (
      object.encoding === 'base64' &&
      typeof object.data === 'string'
    ) {
      return object.data;
    }
  }

  throw new Error(
    'Unexpected image_data format',
  );
}

function readPhoneExport(): PhoneExport {
  if (!existsSync(EXPORT_PATH)) {
    throw new Error(
      `Phone export not found: ${EXPORT_PATH}`,
    );
  }

  const phone = JSON.parse(
    readFileSync(EXPORT_PATH, 'utf8'),
  ) as PhoneExport;

  if (
    phone.format !==
    'pharmaflow-phone-bootstrap-v1'
  ) {
    throw new Error(
      `Unexpected phone export format: ${phone.format}`,
    );
  }

  return phone;
}

function getRowsWithoutUuid(
  rows: JsonRow[],
): JsonRow[] {
  return rows.filter(
    (row) =>
      nullableString(row.server_uuid) === null,
  );
}

function createOrLoadAssignments(
  phone: PhoneExport,
): AssignmentFile {
  const companiesWithoutUuid =
    getRowsWithoutUuid(phone.companies);

  const chequesWithoutUuid =
    getRowsWithoutUuid(phone.cheques);

  if (companiesWithoutUuid.length !== 1) {
    throw new Error(
      `Expected exactly 1 Company without UUID, found ${companiesWithoutUuid.length}`,
    );
  }

  if (chequesWithoutUuid.length !== 3) {
    throw new Error(
      `Expected exactly 3 Cheques without UUID, found ${chequesWithoutUuid.length}`,
    );
  }

  if (existsSync(ASSIGNMENTS_PATH)) {
    const existing = JSON.parse(
      readFileSync(
        ASSIGNMENTS_PATH,
        'utf8',
      ),
    ) as AssignmentFile;

    if (
      existing.format !==
      'pharmaflow-phone-bootstrap-uuid-v1'
    ) {
      throw new Error(
        'Unexpected UUID assignment file format',
      );
    }

    return existing;
  }

  const assignments: AssignmentFile = {
    format:
      'pharmaflow-phone-bootstrap-uuid-v1',

    company:
      companiesWithoutUuid.map(
        (row) => ({
          localId: requiredInt(
            row.id,
            'companies.id',
          ),
          uuid: randomUUID(),
        }),
      ),

    cheques:
      chequesWithoutUuid.map(
        (row) => ({
          localId: requiredInt(
            row.id,
            'cheques.id',
          ),
          uuid: randomUUID(),
        }),
      ),
  };

  writeFileSync(
    ASSIGNMENTS_PATH,
    JSON.stringify(
      assignments,
      null,
      2,
    ),
    'utf8',
  );

  return assignments;
}

function assignmentMap(
  assignments: UuidAssignment[],
): Map<number, string> {
  return new Map(
    assignments.map(
      (item) => [
        item.localId,
        item.uuid,
      ],
    ),
  );
}

function resolveEntityUuid(
  row: JsonRow,
  generated: Map<number, string>,
  entityName: string,
): string {
  const existing =
    nullableString(row.server_uuid);

  if (existing) {
    return existing;
  }

  const localId =
    requiredInt(
      row.id,
      `${entityName}.id`,
    );

  const assigned =
    generated.get(localId);

  if (!assigned) {
    throw new Error(
      `No generated UUID found for ${entityName} localId=${localId}`,
    );
  }

  return assigned;
}

async function main() {
  console.log('');
  console.log(
    '========================================',
  );
  console.log(
    'PHARMAFLOW PHONE -> LIARA IMPORT',
  );
  console.log(
    '========================================',
  );

  const phone =
    readPhoneExport();

  console.log('');
  console.log('SOURCE:');
  console.log(
    `  Companies: ${phone.companies.length}`,
  );
  console.log(
    `  BankAccounts: ${phone.bankAccounts.length}`,
  );
  console.log(
    `  Cheques: ${phone.cheques.length}`,
  );

  if (
    phone.companies.length !== 83 ||
    phone.bankAccounts.length !== 3 ||
    phone.cheques.length !== 731
  ) {
    throw new Error(
      'Source counts do not match audited phone database.',
    );
  }

  const assignments =
    createOrLoadAssignments(phone);

  const companyGenerated =
    assignmentMap(assignments.company);

  const chequeGenerated =
    assignmentMap(assignments.cheques);

  console.log('');
  console.log('UUID ASSIGNMENTS:');

  for (
    const assignment
    of assignments.company
  ) {
    console.log(
      `  COMPANY localId=${assignment.localId} -> ${assignment.uuid}`,
    );
  }

  for (
    const assignment
    of assignments.cheques
  ) {
    console.log(
      `  CHEQUE localId=${assignment.localId} -> ${assignment.uuid}`,
    );
  }

  const companyUuidByLocalId =
    new Map<number, string>();

  for (const row of phone.companies) {
    const localId =
      requiredInt(
        row.id,
        'companies.id',
      );

    companyUuidByLocalId.set(
      localId,
      resolveEntityUuid(
        row,
        companyGenerated,
        'Company',
      ),
    );
  }

  const bankUuidByLocalId =
    new Map<number, string>();

  for (
    const row of phone.bankAccounts
  ) {
    const localId =
      requiredInt(
        row.id,
        'bank_accounts.id',
      );

    const uuid =
      nullableString(row.server_uuid);

    if (!uuid) {
      throw new Error(
        `BankAccount localId=${localId} has no server UUID`,
      );
    }

    bankUuidByLocalId.set(
      localId,
      uuid,
    );
  }

  const companyData:
    Prisma.CompanyCreateManyInput[] =
    phone.companies.map(
      (row) => {
        const localId =
          requiredInt(
            row.id,
            'companies.id',
          );

        const id =
          companyUuidByLocalId.get(
            localId,
          );

        if (!id) {
          throw new Error(
            `Company UUID resolution failed for localId=${localId}`,
          );
        }

        return {
          id,

          name:
            requiredString(
              row.name,
              'companies.name',
            ),

          nationalId:
            nullableString(
              row.national_id,
            ),

          economicCode:
            nullableString(
              row.economic_code,
            ),

          bankName: null,
          accountNumber: null,
          cardNumber: null,
          shebaNumber: null,

          notes:
            nullableString(
              row.notes,
            ),

          visitorName:
            nullableString(
              row.visitor_name,
            ),

          visitorPhone:
            nullableString(
              row.visitor_phone,
            ),

          accountantName:
            nullableString(
              row.accountant_name,
            ),

          accountantPhone:
            nullableString(
              row.accountant_phone,
            ),

          createdAt:
            requiredDate(
              row.created_at,
              'companies.created_at',
            ),

          updatedAt:
            requiredDate(
              row.updated_at,
              'companies.updated_at',
            ),

          archivedAt:
            nullableDate(
              row.archived_at,
              'companies.archived_at',
            ),

          deletedAt: null,
        };
      },
    );

  const bankData:
    Prisma.BankAccountCreateManyInput[] =
    phone.bankAccounts.map(
      (row) => {
        const localId =
          requiredInt(
            row.id,
            'bank_accounts.id',
          );

        const id =
          bankUuidByLocalId.get(
            localId,
          );

        if (!id) {
          throw new Error(
            `BankAccount UUID resolution failed for localId=${localId}`,
          );
        }

        return {
          id,

          bankName:
            requiredString(
              row.bank_name,
              'bank_accounts.bank_name',
            ),

          accountTitle:
            nullableString(
              row.account_title,
            ),

          accountHolder:
            nullableString(
              row.account_holder,
            ),

          accountNumber:
            nullableString(
              row.account_number,
            ),

          cardNumber:
            nullableString(
              row.card_number,
            ),

          shebaNumber:
            nullableString(
              row.iban,
            ),

          notes:
            nullableString(
              row.note,
            ),

          createdAt:
            requiredDate(
              row.created_at,
              'bank_accounts.created_at',
            ),

          updatedAt:
            requiredDate(
              row.updated_at,
              'bank_accounts.updated_at',
            ),

          archivedAt:
            nullableDate(
              row.archived_at,
              'bank_accounts.archived_at',
            ),

          deletedAt: null,
        };
      },
    );

  const chequeIds: string[] = [];

  const chequeData:
    Prisma.ChequeCreateManyInput[] =
    phone.cheques.map(
      (row) => {
        const localId =
          requiredInt(
            row.id,
            'cheques.id',
          );

        const id =
          resolveEntityUuid(
            row,
            chequeGenerated,
            'Cheque',
          );

        chequeIds.push(id);

        const localCompanyId =
          requiredInt(
            row.company_id,
            'cheques.company_id',
          );

        const localBankId =
          requiredInt(
            row.bank_account_id,
            'cheques.bank_account_id',
          );

        const companyId =
          companyUuidByLocalId.get(
            localCompanyId,
          );

        const bankAccountId =
          bankUuidByLocalId.get(
            localBankId,
          );

        if (!companyId) {
          throw new Error(
            `Missing Company mapping for Cheque localId=${localId}, companyLocalId=${localCompanyId}`,
          );
        }

        if (!bankAccountId) {
          throw new Error(
            `Missing BankAccount mapping for Cheque localId=${localId}, bankLocalId=${localBankId}`,
          );
        }

        return {
          id,

          chequeNumber:
            requiredString(
              row.cheque_number,
              'cheques.cheque_number',
            ),

          amount:
            new Prisma.Decimal(
              String(
                requiredInt(
                  row.amount_rial,
                  'cheques.amount_rial',
                ),
              ),
            ),

          chequeDate:
            requiredDate(
              row.issue_date,
              'cheques.issue_date',
            ),

          dueDate:
            nullableDate(
              row.due_date,
              'cheques.due_date',
            ),

          status:
            nullableString(
              row.status,
            ),

          companyId,
          bankAccountId,

          sayadStatus: null,

          isRegisteredInSayad:
            booleanFromFlag(
              row.is_registered_in_sayad,
            ),

          sayadId:
            nullableString(
              row.sayad_id,
            ),

          imagePath: null,

          imageData:
            imageDataFromExport(
              row.image_data,
            ),

          description:
            nullableString(
              row.description,
            ),

          createdAt:
            requiredDate(
              row.created_at,
              'cheques.created_at',
            ),

          updatedAt:
            requiredDate(
              row.updated_at,
              'cheques.updated_at',
            ),

          archivedAt:
            nullableDate(
              row.archived_at,
              'cheques.archived_at',
            ),

          deletedAt:
            nullableDate(
              row.delete_requested_at,
              'cheques.delete_requested_at',
            ),
        };
      },
    );

  const companyIds: string[] =
    phone.companies.map((row) => {
      const localId = requiredInt(
        row.id,
        'companies.id',
      );

      const id =
        companyUuidByLocalId.get(localId);

      if (!id) {
        throw new Error(
          `Company UUID missing for localId=${localId}`,
        );
      }

      return id;
    });

  const bankIds: string[] =
    phone.bankAccounts.map((row) => {
      const localId = requiredInt(
        row.id,
        'bank_accounts.id',
      );

      const id =
        bankUuidByLocalId.get(localId);

      if (!id) {
        throw new Error(
          `BankAccount UUID missing for localId=${localId}`,
        );
      }

      return id;
    });

  /*
   * Final safety checks against the
   * CURRENT server state.
   */
  const [
    serverCompanies,
    serverBanks,
    serverCheques,
  ] = await Promise.all([
    prisma.company.findMany(),
    prisma.bankAccount.findMany(),
    prisma.cheque.findMany(),
  ]);

  const phoneCompanyIds =
    new Set(companyIds);

  const phoneBankIds =
    new Set(bankIds);

  const phoneChequeIds =
    new Set(chequeIds);

  const activeServerOnlyCompanies =
    serverCompanies.filter(
      (row) =>
        row.deletedAt === null &&
        !phoneCompanyIds.has(row.id),
    );

  const activeServerOnlyBanks =
    serverBanks.filter(
      (row) =>
        row.deletedAt === null &&
        !phoneBankIds.has(row.id),
    );

  const activeServerOnlyCheques =
    serverCheques.filter(
      (row) =>
        row.deletedAt === null &&
        !phoneChequeIds.has(row.id),
    );

  if (
    activeServerOnlyCompanies.length >
      0 ||
    activeServerOnlyBanks.length > 0 ||
    activeServerOnlyCheques.length > 0
  ) {
    throw new Error(
      'ABORTED: Active server-only records appeared after Dry Run.',
    );
  }

  for (
    const company
    of companyData
  ) {
    const conflict =
      serverCompanies.find(
        (server) =>
          server.name === company.name &&
          server.id !== company.id,
      );

    if (conflict) {
      throw new Error(
        `ABORTED: Company name conflict for "${company.name}"`,
      );
    }
  }

  /*
   * Back up current server state before
   * performing the transaction.
   */
  writeFileSync(
    SERVER_BACKUP_PATH,
    JSON.stringify(
      {
        createdAt:
          new Date().toISOString(),

        companies:
          serverCompanies,

        bankAccounts:
          serverBanks,

        cheques:
          serverCheques,
      },
      null,
      2,
    ),
    'utf8',
  );

  console.log('');
  console.log(
    `Server backup written to:`,
  );
  console.log(
    `  ${SERVER_BACKUP_PATH}`,
  );

  console.log('');
  console.log(
    'STARTING DATABASE TRANSACTION...',
  );

  const result =
    await prisma.$transaction(
      async (tx) => {
        const companies =
          await tx.company.createMany({
            data: companyData,
            skipDuplicates: true,
          });

        const banks =
          await tx.bankAccount.createMany({
            data: bankData,
            skipDuplicates: true,
          });

        const cheques =
          await tx.cheque.createMany({
            data: chequeData,
            skipDuplicates: true,
          });

        return {
          companies:
            companies.count,
          bankAccounts:
            banks.count,
          cheques:
            cheques.count,
        };
      },
      {
        maxWait: 10000,
        timeout: 120000,
      },
    );

  console.log('');
  console.log(
    'TRANSACTION COMMITTED.',
  );

  console.log('');
  console.log('INSERTED:');
  console.log(
    `  Companies: ${result.companies}`,
  );
  console.log(
    `  BankAccounts: ${result.bankAccounts}`,
  );
  console.log(
    `  Cheques: ${result.cheques}`,
  );

  /*
   * Verify phone-scope records,
   * regardless of unrelated soft-deleted
   * test records on server.
   */
  const [
    importedCompanies,
    importedBanks,
    importedCheques,
    activeImportedCheques,
    deletedImportedCheques,
  ] = await Promise.all([
    prisma.company.count({
      where: {
        id: {
          in: companyIds,
        },
      },
    }),

    prisma.bankAccount.count({
      where: {
        id: {
          in: bankIds,
        },
      },
    }),

    prisma.cheque.count({
      where: {
        id: {
          in: chequeIds,
        },
      },
    }),

    prisma.cheque.count({
      where: {
        id: {
          in: chequeIds,
        },
        deletedAt: null,
      },
    }),

    prisma.cheque.count({
      where: {
        id: {
          in: chequeIds,
        },
        deletedAt: {
          not: null,
        },
      },
    }),
  ]);

  console.log('');
  console.log(
    '========================================',
  );
  console.log('POST-IMPORT VERIFY');
  console.log(
    '========================================',
  );

  console.log(
    `Companies present: ${importedCompanies} / ${companyData.length}`,
  );

  console.log(
    `BankAccounts present: ${importedBanks} / ${bankData.length}`,
  );

  console.log(
    `Cheques present: ${importedCheques} / ${chequeData.length}`,
  );

  console.log(
    `Active imported Cheques: ${activeImportedCheques}`,
  );

  console.log(
    `Soft-deleted imported Cheques: ${deletedImportedCheques}`,
  );

  const verificationOk =
    importedCompanies ===
      companyData.length &&
    importedBanks ===
      bankData.length &&
    importedCheques ===
      chequeData.length &&
    activeImportedCheques === 730 &&
    deletedImportedCheques === 1;

  console.log('');
  console.log(
    `IMPORT VERIFIED: ${
      verificationOk
        ? 'YES'
        : 'NO'
    }`,
  );

  console.log('');
  console.log(
    `UUID assignment file:`,
  );

  console.log(
    `  ${ASSIGNMENTS_PATH}`,
  );

  if (!verificationOk) {
    throw new Error(
      'Import committed, but post-import verification did not match expected phone dataset.',
    );
  }

  console.log('');
  console.log(
    'PHONE DATABASE WAS NOT MODIFIED.',
  );

  console.log(
    'SYNC QUEUE WAS NOT MODIFIED.',
  );

  console.log('');
  console.log(
    'NEXT STEP: backfill the 4 generated UUIDs into the phone safely.',
  );
}

main()
  .catch((error) => {
    console.error('');
    console.error(
      'IMPORT FAILED:',
    );
    console.error(error);

    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });