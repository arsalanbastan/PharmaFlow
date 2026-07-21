import 'package:sqlite3/sqlite3.dart';

import 'queries/company_queries.dart';

class MigrationManager {
  const MigrationManager._();

  static const int currentVersion = 2;

  static void migrate(Database db) {
    final version =
        db.select(
          'PRAGMA user_version',
        ).first['user_version'] as int;

    if (version >= currentVersion) {
      return;
    }

    if (version < 1) {
      _createVersion1(db);
    }

    if (version < 2) {
      _addVisitorAndAccountantColumns(db);
    }

    db.execute(
      'PRAGMA user_version = $currentVersion',
    );
  }

  static void _createVersion1(Database db) {
    db.execute(
      'PRAGMA foreign_keys = ON;',
    );

    db.execute(
      CompanyQueries.createTable,
    );

    db.execute(
      CompanyQueries.createIndexes,
    );
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
}
