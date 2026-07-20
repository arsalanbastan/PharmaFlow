import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'migration_manager.dart';
import 'seed_manager.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  static const _databaseName = 'pharmaflow.db';

  Database? _database;

  Database get database {
    if (_database == null) {
      throw StateError(
        'Database has not been initialized.\n'
        'Call DatabaseService.instance.initialize() first.',
      );
    }

    return _database!;
  }

  bool get isInitialized => _database != null;

  Future<void> initialize() async {
    if (_database != null) return;

    final documents = await getApplicationDocumentsDirectory();

    final dbPath = p.join(
      documents.path,
      _databaseName,
    );

    final file = File(dbPath);

    if (!await file.exists()) {
      await file.create(recursive: true);
    }

    final db = sqlite3.open(dbPath);

    MigrationManager.migrate(db);

    SeedManager.seed(db);

    _database = db;
  }

  void close() {
    _database?.dispose();
    _database = null;
  }

  void transaction(void Function(Database db) action) {
    database.execute('BEGIN TRANSACTION');

    try {
      action(database);

      database.execute('COMMIT');
    } catch (_) {
      database.execute('ROLLBACK');

      rethrow;
    }
  }
}