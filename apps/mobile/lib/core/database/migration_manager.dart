import 'package:sqlite3/sqlite3.dart';

import 'queries/company_queries.dart';

class MigrationManager {
  const MigrationManager._();

  static const int currentVersion = 1;

  static void migrate(Database db) {
    final version =
        db.select(
          'PRAGMA user_version',
        ).first['user_version'] as int;

    if (version >= currentVersion) {
      return;
    }

    _createVersion1(db);

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
}