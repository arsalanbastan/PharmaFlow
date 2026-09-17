import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';

import { Prisma, PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

const EXPORT_PATH = 'D:\\PharmaFlowBootstrap\\phone_bootstrap_export.json';
const ASSIGNMENTS_PATH =
  'D:\\PharmaFlowBootstrap\\phone_uuid_assignments.json';
const REPORT_PATH = 'D:\\PharmaFlowBootstrap\\strong_verify_report.json';

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

type EntityType = 'COMPANY' | 'BANK_ACCOUNT' | 'CHEQUE';

interface FieldMismatch {
  type: 'FIELD_MISMATCH' | 'IMAGE_MISMATCH' | 'FK_MISMATCH' | 'SOFT_DELETE_MISMATCH';
  entityType: EntityType;
  localId: number | null;
  serverUuid: string;
  field: string;
  expected: unknown;
  actual: unknown;
}

interface MissingServerRecord {
  entityType: EntityType;
  localId: number;
  serverUuid: string;
}

interface ServerOnlyRecord {
  entityType: EntityType;
  serverUuid: string;
}

interface VerifierReport {
  generatedAt: string;
  input: {
    exportPath: string;
    assignmentsPath: string;
  };
  expectedCounts: {
    companies: number;
    bankAccounts: number;
    cheques: number;
  };
  exactCounts: {
    companies: number;
    bankAccounts: number;
    cheques: number;
  };
  summary: {
    fieldMismatches: number;
    missingServerRecords: number;
    serverOnlyRecords: number;
    fkMismatches: number;
    receiverNameNonEmpty: number;
    imageMismatches: number;
    softDeleteMismatches: number;
    duplicateExpectedUuids: number;
  };
  assertions: {
    expectedCompanyUuidCount83: boolean;
    expectedBankUuidCount3: boolean;
    expectedChequeUuidCount731: boolean;
    noDuplicateExpectedUuids: boolean;
    receiverNameNonEmptyIsZero: boolean;
  };
  missingServerRecords: MissingServerRecord[];
  serverOnlyRecords: ServerOnlyRecord[];
  mismatches: FieldMismatch[];
  duplicateExpectedUuids: {
    companies: string[];
    bankAccounts: string[];
    cheques: string[];
  };
}

function requiredInt(value: unknown, field: string): number {
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) {
      throw new Error(`Invalid number for ${field}: ${value}`);
    }

    return Math.trunc(value);
  }

  if (typeof value === 'string') {
    const parsed = Number(value);

    if (Number.isFinite(parsed)) {
      return Math.trunc(parsed);
    }
  }

  throw new Error(`Expected integer-compatible value for ${field}`);
}

function requiredString(value: unknown, field: string): string {
  if (typeof value !== 'string') {
    throw new Error(`Expected string for ${field}`);
  }

  return value;
}

function nullableString(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value !== 'string') {
    return String(value);
  }

  const trimmed = value.trim();

  return trimmed.length === 0 ? null : trimmed;
}

function requiredDate(value: unknown, field: string): Date {
  const milliseconds = requiredInt(value, field);
  const date = new Date(milliseconds);

  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date for ${field}: ${value}`);
  }

  return date;
}

function nullableDate(value: unknown, field: string): Date | null {
  if (value === null || value === undefined) {
    return null;
  }

  return requiredDate(value, field);
}

function booleanFromFlag(value: unknown): boolean {
  if (typeof value === 'boolean') {
    return value;
  }

  if (typeof value === 'number') {
    return value !== 0;
  }

  if (typeof value === 'string') {
    const normalized = value.trim().toLowerCase();
    return normalized === '1' || normalized === 'true';
  }

  return false;
}

function imageDataFromExport(value: unknown): string | null {
  if (value === null || value === undefined) {
    return null;
  }

  if (typeof value === 'string') {
    return value;
  }

  if (typeof value === 'object' && value !== null) {
    const object = value as Record<string, unknown>;

    if (object.encoding === 'base64' && typeof object.data === 'string') {
      return object.data;
    }
  }

  throw new Error('Unexpected image_data format');
}

function assignmentMap(assignments: UuidAssignment[]): Map<number, string> {
  return new Map(assignments.map((item) => [item.localId, item.uuid]));
}

function resolveEntityUuid(
  row: JsonRow,
  generated: Map<number, string>,
  entityName: string,
): string {
  const existing = nullableString(row.server_uuid);

  if (existing) {
    return existing;
  }

  const localId = requiredInt(row.id, `${entityName}.id`);
  const assigned = generated.get(localId);

  if (!assigned) {
    throw new Error(`No generated UUID found for ${entityName} localId=${localId}`);
  }

  return assigned;
}

function readPhoneExport(): PhoneExport {
  if (!existsSync(EXPORT_PATH)) {
    throw new Error(`Phone export not found: ${EXPORT_PATH}`);
  }

  const phone = JSON.parse(readFileSync(EXPORT_PATH, 'utf8')) as PhoneExport;

  if (phone.format !== 'pharmaflow-phone-bootstrap-v1') {
    throw new Error(`Unexpected phone export format: ${phone.format}`);
  }

  return phone;
}

function readAssignments(): AssignmentFile {
  if (!existsSync(ASSIGNMENTS_PATH)) {
    throw new Error(`UUID assignment file not found: ${ASSIGNMENTS_PATH}`);
  }

  const assignments = JSON.parse(readFileSync(ASSIGNMENTS_PATH, 'utf8')) as AssignmentFile;

  if (assignments.format !== 'pharmaflow-phone-bootstrap-uuid-v1') {
    throw new Error('Unexpected UUID assignment file format');
  }

  return assignments;
}

function dateMillisOrNull(value: Date | null): number | null {
  return value === null ? null : value.getTime();
}

function normalizedImageInfo(value: string | null): { length: number; sha256: string } | null {
  if (value === null) {
    return null;
  }

  return {
    length: value.length,
    sha256: createHash('sha256').update(value).digest('hex'),
  };
}

function addFieldMismatch(
  mismatches: FieldMismatch[],
  counters: {
    fieldMismatches: number;
    fkMismatches: number;
    imageMismatches: number;
    softDeleteMismatches: number;
  },
  mismatch: FieldMismatch,
): void {
  mismatches.push(mismatch);

  if (mismatch.type === 'FK_MISMATCH') {
    counters.fkMismatches += 1;
    return;
  }

  if (mismatch.type === 'IMAGE_MISMATCH') {
    counters.imageMismatches += 1;
    return;
  }

  if (mismatch.type === 'SOFT_DELETE_MISMATCH') {
    counters.softDeleteMismatches += 1;
    return;
  }

  counters.fieldMismatches += 1;
}

function duplicateValues(values: string[]): string[] {
  const counts = new Map<string, number>();

  for (const value of values) {
    counts.set(value, (counts.get(value) ?? 0) + 1);
  }

  return [...counts.entries()]
    .filter((entry) => entry[1] > 1)
    .map((entry) => entry[0]);
}

async function main() {
  const phone = readPhoneExport();
  const assignments = readAssignments();

  const companyGenerated = assignmentMap(assignments.company);
  const chequeGenerated = assignmentMap(assignments.cheques);

  const expectedCompanies = new Map<
    string,
    {
      localId: number;
      name: string;
      nationalId: string | null;
      economicCode: string | null;
      bankName: null;
      accountNumber: null;
      cardNumber: null;
      shebaNumber: null;
      notes: string | null;
      visitorName: string | null;
      visitorPhone: string | null;
      accountantName: string | null;
      accountantPhone: string | null;
      createdAtMs: number;
      updatedAtMs: number;
      archivedAtMs: number | null;
      deletedAtMs: null;
    }
  >();

  const companyUuidByLocalId = new Map<number, string>();

  for (const row of phone.companies) {
    const localId = requiredInt(row.id, 'companies.id');
    const serverUuid = resolveEntityUuid(row, companyGenerated, 'Company');

    companyUuidByLocalId.set(localId, serverUuid);

    expectedCompanies.set(serverUuid, {
      localId,
      name: requiredString(row.name, 'companies.name'),
      nationalId: nullableString(row.national_id),
      economicCode: nullableString(row.economic_code),
      bankName: null,
      accountNumber: null,
      cardNumber: null,
      shebaNumber: null,
      notes: nullableString(row.notes),
      visitorName: nullableString(row.visitor_name),
      visitorPhone: nullableString(row.visitor_phone),
      accountantName: nullableString(row.accountant_name),
      accountantPhone: nullableString(row.accountant_phone),
      createdAtMs: requiredDate(row.created_at, 'companies.created_at').getTime(),
      updatedAtMs: requiredDate(row.updated_at, 'companies.updated_at').getTime(),
      archivedAtMs: dateMillisOrNull(nullableDate(row.archived_at, 'companies.archived_at')),
      deletedAtMs: null,
    });
  }

  const expectedBanks = new Map<
    string,
    {
      localId: number;
      bankName: string;
      accountTitle: string | null;
      accountHolder: string | null;
      accountNumber: string | null;
      cardNumber: string | null;
      shebaNumber: string | null;
      notes: string | null;
      createdAtMs: number;
      updatedAtMs: number;
      archivedAtMs: number | null;
      deletedAtMs: null;
    }
  >();

  const bankUuidByLocalId = new Map<number, string>();

  for (const row of phone.bankAccounts) {
    const localId = requiredInt(row.id, 'bank_accounts.id');
    const serverUuid = nullableString(row.server_uuid);

    if (!serverUuid) {
      throw new Error(`BankAccount localId=${localId} has no server UUID`);
    }

    bankUuidByLocalId.set(localId, serverUuid);

    expectedBanks.set(serverUuid, {
      localId,
      bankName: requiredString(row.bank_name, 'bank_accounts.bank_name'),
      accountTitle: nullableString(row.account_title),
      accountHolder: nullableString(row.account_holder),
      accountNumber: nullableString(row.account_number),
      cardNumber: nullableString(row.card_number),
      shebaNumber: nullableString(row.iban),
      notes: nullableString(row.note),
      createdAtMs: requiredDate(row.created_at, 'bank_accounts.created_at').getTime(),
      updatedAtMs: requiredDate(row.updated_at, 'bank_accounts.updated_at').getTime(),
      archivedAtMs: dateMillisOrNull(nullableDate(row.archived_at, 'bank_accounts.archived_at')),
      deletedAtMs: null,
    });
  }

  const expectedCheques = new Map<
    string,
    {
      localId: number;
      chequeNumber: string;
      amountAsIntString: string;
      chequeDateMs: number;
      dueDateMs: number | null;
      status: string | null;
      companyId: string;
      bankAccountId: string;
      sayadStatus: null;
      isRegisteredInSayad: boolean;
      sayadId: string | null;
      imagePath: null;
      imageData: string | null;
      description: string | null;
      createdAtMs: number;
      updatedAtMs: number;
      archivedAtMs: number | null;
      deletedAtMs: number | null;
    }
  >();

  let receiverNameNonEmpty = 0;

  for (const row of phone.cheques) {
    const localId = requiredInt(row.id, 'cheques.id');
    const serverUuid = resolveEntityUuid(row, chequeGenerated, 'Cheque');

    const receiverName = nullableString(row.receiver_name);
    if (receiverName !== null) {
      receiverNameNonEmpty += 1;
    }

    const localCompanyId = requiredInt(row.company_id, 'cheques.company_id');
    const localBankId = requiredInt(row.bank_account_id, 'cheques.bank_account_id');

    const companyId = companyUuidByLocalId.get(localCompanyId);
    const bankAccountId = bankUuidByLocalId.get(localBankId);

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

    expectedCheques.set(serverUuid, {
      localId,
      chequeNumber: requiredString(row.cheque_number, 'cheques.cheque_number'),
      amountAsIntString: String(requiredInt(row.amount_rial, 'cheques.amount_rial')),
      chequeDateMs: requiredDate(row.issue_date, 'cheques.issue_date').getTime(),
      dueDateMs: dateMillisOrNull(nullableDate(row.due_date, 'cheques.due_date')),
      status: nullableString(row.status),
      companyId,
      bankAccountId,
      sayadStatus: null,
      isRegisteredInSayad: booleanFromFlag(row.is_registered_in_sayad),
      sayadId: nullableString(row.sayad_id),
      imagePath: null,
      imageData: imageDataFromExport(row.image_data),
      description: nullableString(row.description),
      createdAtMs: requiredDate(row.created_at, 'cheques.created_at').getTime(),
      updatedAtMs: requiredDate(row.updated_at, 'cheques.updated_at').getTime(),
      archivedAtMs: dateMillisOrNull(nullableDate(row.archived_at, 'cheques.archived_at')),
      deletedAtMs: dateMillisOrNull(nullableDate(row.delete_requested_at, 'cheques.delete_requested_at')),
    });
  }

  const duplicateExpectedCompanyUuids = duplicateValues([...expectedCompanies.keys()]);
  const duplicateExpectedBankUuids = duplicateValues([...expectedBanks.keys()]);
  const duplicateExpectedChequeUuids = duplicateValues([...expectedCheques.keys()]);

  const [serverCompanies, serverBankAccounts, serverCheques] = await Promise.all([
    prisma.company.findMany(),
    prisma.bankAccount.findMany(),
    prisma.cheque.findMany(),
  ]);

  const serverCompaniesById = new Map(serverCompanies.map((row) => [row.id, row]));
  const serverBanksById = new Map(serverBankAccounts.map((row) => [row.id, row]));
  const serverChequesById = new Map(serverCheques.map((row) => [row.id, row]));

  const missingServerRecords: MissingServerRecord[] = [];
  const serverOnlyRecords: ServerOnlyRecord[] = [];
  const mismatches: FieldMismatch[] = [];

  const counters = {
    fieldMismatches: 0,
    fkMismatches: 0,
    imageMismatches: 0,
    softDeleteMismatches: 0,
  };

  let exactCompanies = 0;
  let exactBanks = 0;
  let exactCheques = 0;

  for (const [uuid, expected] of expectedCompanies.entries()) {
    const actual = serverCompaniesById.get(uuid);

    if (!actual) {
      missingServerRecords.push({ entityType: 'COMPANY', localId: expected.localId, serverUuid: uuid });
      continue;
    }

    let entityHasMismatch = false;

    const fieldChecks: Array<[string, unknown, unknown]> = [
      ['id', expected.localId === null ? null : uuid, actual.id],
      ['name', expected.name, actual.name],
      ['nationalId', expected.nationalId, actual.nationalId],
      ['economicCode', expected.economicCode, actual.economicCode],
      ['bankName', expected.bankName, actual.bankName],
      ['accountNumber', expected.accountNumber, actual.accountNumber],
      ['cardNumber', expected.cardNumber, actual.cardNumber],
      ['shebaNumber', expected.shebaNumber, actual.shebaNumber],
      ['notes', expected.notes, actual.notes],
      ['visitorName', expected.visitorName, actual.visitorName],
      ['visitorPhone', expected.visitorPhone, actual.visitorPhone],
      ['accountantName', expected.accountantName, actual.accountantName],
      ['accountantPhone', expected.accountantPhone, actual.accountantPhone],
      ['createdAt', expected.createdAtMs, actual.createdAt.getTime()],
      ['updatedAt', expected.updatedAtMs, actual.updatedAt.getTime()],
      ['archivedAt', expected.archivedAtMs, dateMillisOrNull(actual.archivedAt)],
    ];

    for (const [field, exp, act] of fieldChecks) {
      if (exp !== act) {
        entityHasMismatch = true;
        addFieldMismatch(mismatches, counters, {
          type: 'FIELD_MISMATCH',
          entityType: 'COMPANY',
          localId: expected.localId,
          serverUuid: uuid,
          field,
          expected: exp,
          actual: act,
        });
      }
    }

    const expectedDeletedAt = expected.deletedAtMs;
    const actualDeletedAt = dateMillisOrNull(actual.deletedAt);

    if (expectedDeletedAt !== actualDeletedAt) {
      entityHasMismatch = true;
      addFieldMismatch(mismatches, counters, {
        type: 'SOFT_DELETE_MISMATCH',
        entityType: 'COMPANY',
        localId: expected.localId,
        serverUuid: uuid,
        field: 'deletedAt',
        expected: expectedDeletedAt,
        actual: actualDeletedAt,
      });
    }

    if (!entityHasMismatch) {
      exactCompanies += 1;
    }
  }

  for (const [uuid, expected] of expectedBanks.entries()) {
    const actual = serverBanksById.get(uuid);

    if (!actual) {
      missingServerRecords.push({ entityType: 'BANK_ACCOUNT', localId: expected.localId, serverUuid: uuid });
      continue;
    }

    let entityHasMismatch = false;

    const fieldChecks: Array<[string, unknown, unknown]> = [
      ['id', expected.localId === null ? null : uuid, actual.id],
      ['bankName', expected.bankName, actual.bankName],
      ['accountTitle', expected.accountTitle, actual.accountTitle],
      ['accountHolder', expected.accountHolder, actual.accountHolder],
      ['accountNumber', expected.accountNumber, actual.accountNumber],
      ['cardNumber', expected.cardNumber, actual.cardNumber],
      ['shebaNumber', expected.shebaNumber, actual.shebaNumber],
      ['notes', expected.notes, actual.notes],
      ['createdAt', expected.createdAtMs, actual.createdAt.getTime()],
      ['updatedAt', expected.updatedAtMs, actual.updatedAt.getTime()],
      ['archivedAt', expected.archivedAtMs, dateMillisOrNull(actual.archivedAt)],
    ];

    for (const [field, exp, act] of fieldChecks) {
      if (exp !== act) {
        entityHasMismatch = true;
        addFieldMismatch(mismatches, counters, {
          type: 'FIELD_MISMATCH',
          entityType: 'BANK_ACCOUNT',
          localId: expected.localId,
          serverUuid: uuid,
          field,
          expected: exp,
          actual: act,
        });
      }
    }

    const expectedDeletedAt = expected.deletedAtMs;
    const actualDeletedAt = dateMillisOrNull(actual.deletedAt);

    if (expectedDeletedAt !== actualDeletedAt) {
      entityHasMismatch = true;
      addFieldMismatch(mismatches, counters, {
        type: 'SOFT_DELETE_MISMATCH',
        entityType: 'BANK_ACCOUNT',
        localId: expected.localId,
        serverUuid: uuid,
        field: 'deletedAt',
        expected: expectedDeletedAt,
        actual: actualDeletedAt,
      });
    }

    if (!entityHasMismatch) {
      exactBanks += 1;
    }
  }

  for (const [uuid, expected] of expectedCheques.entries()) {
    const actual = serverChequesById.get(uuid);

    if (!actual) {
      missingServerRecords.push({ entityType: 'CHEQUE', localId: expected.localId, serverUuid: uuid });
      continue;
    }

    let entityHasMismatch = false;

    const fieldChecks: Array<[string, unknown, unknown]> = [
      ['id', expected.localId === null ? null : uuid, actual.id],
      ['chequeNumber', expected.chequeNumber, actual.chequeNumber],
      ['amount', expected.amountAsIntString, actual.amount.toString()],
      ['chequeDate', expected.chequeDateMs, actual.chequeDate.getTime()],
      ['dueDate', expected.dueDateMs, dateMillisOrNull(actual.dueDate)],
      ['status', expected.status, actual.status],
      ['sayadStatus', expected.sayadStatus, actual.sayadStatus],
      ['isRegisteredInSayad', expected.isRegisteredInSayad, actual.isRegisteredInSayad],
      ['sayadId', expected.sayadId, actual.sayadId],
      ['imagePath', expected.imagePath, actual.imagePath],
      ['description', expected.description, actual.description],
      ['createdAt', expected.createdAtMs, actual.createdAt.getTime()],
      ['updatedAt', expected.updatedAtMs, actual.updatedAt.getTime()],
      ['archivedAt', expected.archivedAtMs, dateMillisOrNull(actual.archivedAt)],
    ];

    for (const [field, exp, act] of fieldChecks) {
      if (exp !== act) {
        entityHasMismatch = true;
        addFieldMismatch(mismatches, counters, {
          type: 'FIELD_MISMATCH',
          entityType: 'CHEQUE',
          localId: expected.localId,
          serverUuid: uuid,
          field,
          expected: exp,
          actual: act,
        });
      }
    }

    if (expected.companyId !== actual.companyId) {
      entityHasMismatch = true;
      addFieldMismatch(mismatches, counters, {
        type: 'FK_MISMATCH',
        entityType: 'CHEQUE',
        localId: expected.localId,
        serverUuid: uuid,
        field: 'companyId',
        expected: expected.companyId,
        actual: actual.companyId,
      });
    }

    if (expected.bankAccountId !== actual.bankAccountId) {
      entityHasMismatch = true;
      addFieldMismatch(mismatches, counters, {
        type: 'FK_MISMATCH',
        entityType: 'CHEQUE',
        localId: expected.localId,
        serverUuid: uuid,
        field: 'bankAccountId',
        expected: expected.bankAccountId,
        actual: actual.bankAccountId,
      });
    }

    const expectedDeletedAt = expected.deletedAtMs;
    const actualDeletedAt = dateMillisOrNull(actual.deletedAt);

    if (expectedDeletedAt !== actualDeletedAt) {
      entityHasMismatch = true;
      addFieldMismatch(mismatches, counters, {
        type: 'SOFT_DELETE_MISMATCH',
        entityType: 'CHEQUE',
        localId: expected.localId,
        serverUuid: uuid,
        field: 'deletedAt',
        expected: expectedDeletedAt,
        actual: actualDeletedAt,
      });
    }

    if (expected.imageData !== actual.imageData) {
      entityHasMismatch = true;
      addFieldMismatch(mismatches, counters, {
        type: 'IMAGE_MISMATCH',
        entityType: 'CHEQUE',
        localId: expected.localId,
        serverUuid: uuid,
        field: 'imageData',
        expected: normalizedImageInfo(expected.imageData),
        actual: normalizedImageInfo(actual.imageData),
      });
    }

    if (!entityHasMismatch) {
      exactCheques += 1;
    }
  }

  const expectedCompanyIds = new Set(expectedCompanies.keys());
  const expectedBankIds = new Set(expectedBanks.keys());
  const expectedChequeIds = new Set(expectedCheques.keys());

  for (const row of serverCompanies) {
    if (row.deletedAt === null && !expectedCompanyIds.has(row.id)) {
      serverOnlyRecords.push({ entityType: 'COMPANY', serverUuid: row.id });
    }
  }

  for (const row of serverBankAccounts) {
    if (row.deletedAt === null && !expectedBankIds.has(row.id)) {
      serverOnlyRecords.push({ entityType: 'BANK_ACCOUNT', serverUuid: row.id });
    }
  }

  for (const row of serverCheques) {
    if (row.deletedAt === null && !expectedChequeIds.has(row.id)) {
      serverOnlyRecords.push({ entityType: 'CHEQUE', serverUuid: row.id });
    }
  }

  const expectedCounts = {
    companies: expectedCompanies.size,
    bankAccounts: expectedBanks.size,
    cheques: expectedCheques.size,
  };

  const duplicateExpectedUuidsTotal =
    duplicateExpectedCompanyUuids.length +
    duplicateExpectedBankUuids.length +
    duplicateExpectedChequeUuids.length;

  const assertions = {
    expectedCompanyUuidCount83: expectedCounts.companies === 83,
    expectedBankUuidCount3: expectedCounts.bankAccounts === 3,
    expectedChequeUuidCount731: expectedCounts.cheques === 731,
    noDuplicateExpectedUuids: duplicateExpectedUuidsTotal === 0,
    receiverNameNonEmptyIsZero: receiverNameNonEmpty === 0,
  };

  const failReasons = [
    !assertions.expectedCompanyUuidCount83,
    !assertions.expectedBankUuidCount3,
    !assertions.expectedChequeUuidCount731,
    !assertions.noDuplicateExpectedUuids,
    !assertions.receiverNameNonEmptyIsZero,
    missingServerRecords.length > 0,
    serverOnlyRecords.length > 0,
    counters.fieldMismatches > 0,
    counters.fkMismatches > 0,
    counters.imageMismatches > 0,
    counters.softDeleteMismatches > 0,
    exactCompanies !== 83,
    exactBanks !== 3,
    exactCheques !== 731,
  ];

  const passed = !failReasons.some((value) => value);

  const report: VerifierReport = {
    generatedAt: new Date().toISOString(),
    input: {
      exportPath: EXPORT_PATH,
      assignmentsPath: ASSIGNMENTS_PATH,
    },
    expectedCounts,
    exactCounts: {
      companies: exactCompanies,
      bankAccounts: exactBanks,
      cheques: exactCheques,
    },
    summary: {
      fieldMismatches: counters.fieldMismatches,
      missingServerRecords: missingServerRecords.length,
      serverOnlyRecords: serverOnlyRecords.length,
      fkMismatches: counters.fkMismatches,
      receiverNameNonEmpty,
      imageMismatches: counters.imageMismatches,
      softDeleteMismatches: counters.softDeleteMismatches,
      duplicateExpectedUuids: duplicateExpectedUuidsTotal,
    },
    assertions,
    missingServerRecords,
    serverOnlyRecords,
    mismatches,
    duplicateExpectedUuids: {
      companies: duplicateExpectedCompanyUuids,
      bankAccounts: duplicateExpectedBankUuids,
      cheques: duplicateExpectedChequeUuids,
    },
  };

  writeFileSync(REPORT_PATH, JSON.stringify(report, null, 2), 'utf8');

  if (passed) {
    console.log('STRONG VERIFY: PASS');
    process.exitCode = 0;
  } else {
    console.log('STRONG VERIFY: FAIL');
    process.exitCode = 1;
  }
}

main()
  .catch(() => {
    console.log('STRONG VERIFY: FAIL');
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });

