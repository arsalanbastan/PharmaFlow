import 'package:sqlite3/sqlite3.dart';

import 'queries/bank_account_queries.dart';
import 'queries/cheque_queries.dart';
import 'queries/company_queries.dart';
import 'queries/sync_queue_queries.dart';

class MigrationManager {
  const MigrationManager._();

  static const int currentVersion = 8;

  static void migrate(Database db) {
    db.execute('PRAGMA foreign_keys = ON;');

    final version =
        db.select('PRAGMA user_version').first['user_version'] as int;

    if (version >= currentVersion) {
      return;
    }

    if (version < 1) {
      _createVersion1(db);
    }

    if (version < 2) {
      _addVisitorAndAccountantColumns(db);
    }

    if (version < 3) {
      _createBankAccountsTable(db);
    }

    if (version < 4) {
      _createChequesTable(db);
    }

    if (version < 5) {
      _addChequeSayadIdColumn(db);
    }

    if (version < 6) {
      _createSyncQueueTable(db);
    }

    if (version < 7) {
      _addServerUuidColumns(db);
    }

    if (version < 8) {
      _addChequeSyncColumns(db);
    }

    db.execute('PRAGMA user_version = $currentVersion');
  }

  static void _createVersion1(Database db) {
    db.execute(CompanyQueries.createTable);

    db.execute(CompanyQueries.createIndexes);
  }

  static void _addVisitorAndAccountantColumns(Database db) {
    final tableExists = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'companies'",
    );

    if (tableExists.isEmpty) {
      return;
    }

    final columnsResult = db.select('PRAGMA table_info(companies)');

    final columns = columnsResult.map((row) => row['name'] as String).toSet();

    if (!columns.contains('visitor_name')) {
      db.execute('ALTER TABLE companies ADD COLUMN visitor_name TEXT');
    }

    if (!columns.contains('visitor_phone')) {
      db.execute('ALTER TABLE companies ADD COLUMN visitor_phone TEXT');
    }

    if (!columns.contains('accountant_name')) {
      db.execute('ALTER TABLE companies ADD COLUMN accountant_name TEXT');
    }

    if (!columns.contains('accountant_phone')) {
      db.execute('ALTER TABLE companies ADD COLUMN accountant_phone TEXT');
    }
  }

  static void _createBankAccountsTable(Database db) {
    db.execute(BankAccountQueries.createTable);

    db.execute(BankAccountQueries.createIndexes);
  }

  static void _createChequesTable(Database db) {
    db.execute(ChequeQueries.createTable);

    db.execute(ChequeQueries.createIndexes);
  }

  static void _addChequeSayadIdColumn(Database db) {
    final tableExists = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'cheques'",
    );

    if (tableExists.isEmpty) {
      return;
    }

    final columnsResult = db.select('PRAGMA table_info(cheques)');

    final columns = columnsResult.map((row) => row['name'] as String).toSet();

    if (!columns.contains('sayad_id')) {
      db.execute('ALTER TABLE cheques ADD COLUMN sayad_id TEXT');
    }
  }

  static void _createSyncQueueTable(Database db) {
    db.execute(SyncQueueQueries.createTable);

    db.execute(SyncQueueQueries.createIndexes);
  }

  static void _addServerUuidColumns(Database db) {
    final companyTableExists = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'companies'",
    );

    if (companyTableExists.isNotEmpty) {
      final companyColumnsResult = db.select('PRAGMA table_info(companies)');
      final companyColumns = companyColumnsResult
          .map((row) => row['name'] as String)
          .toSet();

      if (!companyColumns.contains('server_uuid')) {
        db.execute('ALTER TABLE companies ADD COLUMN server_uuid TEXT');
      }
    }

    final bankAccountTableExists = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'bank_accounts'",
    );

    if (bankAccountTableExists.isNotEmpty) {
      final bankAccountColumnsResult = db.select(
        'PRAGMA table_info(bank_accounts)',
      );
      final bankAccountColumns = bankAccountColumnsResult
          .map((row) => row['name'] as String)
          .toSet();

      if (!bankAccountColumns.contains('server_uuid')) {
        db.execute('ALTER TABLE bank_accounts ADD COLUMN server_uuid TEXT');
      }
    }
  }

  static void _addChequeSyncColumns(Database db) {
    final chequeTableExists = db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'cheques'",
    );

    if (chequeTableExists.isEmpty) {
      return;
    }

    final chequeColumnsResult = db.select('PRAGMA table_info(cheques)');
    final chequeColumns = chequeColumnsResult
        .map((row) => row['name'] as String)
        .toSet();

    if (!chequeColumns.contains('server_uuid')) {
      db.execute('ALTER TABLE cheques ADD COLUMN server_uuid TEXT');
    }

    if (!chequeColumns.contains('delete_requested_at')) {
      db.execute('ALTER TABLE cheques ADD COLUMN delete_requested_at INTEGER');
    }
  }
}
