import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_trigger.dart';
import '../../../core/sync/sync_trigger_dispatcher.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../mappers/bank_account_mapper.dart';
import '../../models/bank_account.dart';
import '../exceptions/repository_exceptions.dart';
import '../interfaces/bank_account_repository.dart';
import 'sync_queue_repository.dart';

class LocalBankAccountRepository implements BankAccountRepository {
  LocalBankAccountRepository(this._databaseService);

  final DatabaseService _databaseService;

  SyncQueueRepository get _syncQueueRepository =>
      SyncQueueRepository(_databaseService);

  Database get _db => _databaseService.database;

  String _normalizeAccountTitle(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<BankAccount> _mapAccounts(ResultSet result) {
    return result.map(BankAccountMapper.fromMap).toList();
  }

  @override
  Future<int> insert(BankAccount account) async {
    final normalizedAccountTitle = _normalizeAccountTitle(account.accountTitle);

    if (normalizedAccountTitle.isEmpty) {
      throw ArgumentError('Bank account title cannot be empty.');
    }

    final now = DateTime.now();
    late final int insertedId;

    _databaseService.transaction((db) {
      _throwIfDuplicateTitle(db, normalizedAccountTitle);

      final requestedServerUuid = account.serverUuid?.trim();
      final serverUuid =
          requestedServerUuid != null && requestedServerUuid.isNotEmpty
          ? requestedServerUuid
          : _generateUniqueServerUuid(db);

      _throwIfDuplicateServerUuid(db, serverUuid);

      final values = BankAccountMapper.toMap(
        BankAccount(
          id: null,
          serverUuid: serverUuid,
          bankName: account.bankName,
          accountTitle: normalizedAccountTitle,
          accountHolder: account.accountHolder,
          accountNumber: account.accountNumber,
          cardNumber: account.cardNumber,
          iban: account.iban,
          note: account.note,
          archivedAt: account.archivedAt,
          createdAt: account.createdAt,
          updatedAt: now,
        ),
      );

      final statement = db.prepare('''
INSERT INTO bank_accounts (
  server_uuid,
  bank_name,
  account_title,
  account_holder,
  account_number,
  card_number,
  iban,
  note,
  archived_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''');

      try {
        statement.execute([
          values['server_uuid'],
          values['bank_name'],
          values['account_title'],
          values['account_holder'],
          values['account_number'],
          values['card_number'],
          values['iban'],
          values['note'],
          values['archived_at'],
          values['created_at'],
          values['updated_at'],
        ]);
      } finally {
        statement.dispose();
      }

      insertedId =
          db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

      _syncQueueRepository.addInDatabase(
        db,
        SyncQueueItem(
          entityType: syncEntityTypeBankAccount,
          entityId: insertedId,
          operation: SyncOperation.create,
          status: SyncStatus.pending,
          retryCount: 0,
          createdAt: now,
        ),
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);

    return insertedId;
  }

  @override
  Future<List<BankAccount>> getAll({bool includeArchived = false}) async {
    final result = includeArchived
        ? _db.select('''
SELECT *
FROM bank_accounts
ORDER BY bank_name COLLATE NOCASE,
         account_title COLLATE NOCASE
''')
        : _db.select('''
SELECT *
FROM bank_accounts
WHERE (archived_at IS NULL OR archived_at = 0)
ORDER BY bank_name COLLATE NOCASE,
         account_title COLLATE NOCASE
''');

    return _mapAccounts(result);
  }

  @override
  Future<List<BankAccount>> search(
    String query, {
    bool includeArchived = false,
  }) async {
    final keyword = '%${query.trim()}%';
    final result = _db.select(
      includeArchived
          ? '''
SELECT *
FROM bank_accounts
WHERE (
  LOWER(account_title) LIKE LOWER(?)
  OR LOWER(bank_name) LIKE LOWER(?)
  OR LOWER(account_holder) LIKE LOWER(?)
  OR account_number LIKE ?
  OR card_number LIKE ?
  OR LOWER(iban) LIKE LOWER(?)
)
ORDER BY bank_name COLLATE NOCASE,
         account_title COLLATE NOCASE
'''
          : '''
SELECT *
FROM bank_accounts
WHERE (archived_at IS NULL OR archived_at = 0)
  AND (
    LOWER(account_title) LIKE LOWER(?)
    OR LOWER(bank_name) LIKE LOWER(?)
    OR LOWER(account_holder) LIKE LOWER(?)
    OR account_number LIKE ?
    OR card_number LIKE ?
    OR LOWER(iban) LIKE LOWER(?)
  )
ORDER BY bank_name COLLATE NOCASE,
         account_title COLLATE NOCASE
''',
      [keyword, keyword, keyword, keyword, keyword, keyword],
    );

    return _mapAccounts(result);
  }

  @override
  Future<BankAccount?> getById(int id) async {
    return findById(id);
  }

  @override
  Future<BankAccount?> findById(int id) async {
    final result = _db.select(
      '''
SELECT *
FROM bank_accounts
WHERE id = ?
LIMIT 1
''',
      [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return BankAccountMapper.fromMap(result.first);
  }

  @override
  Future<bool> existsByName(String name) async {
    final normalizedName = _normalizeAccountTitle(name);

    if (normalizedName.isEmpty) {
      return false;
    }

    final result = _db.select(
      '''
SELECT COUNT(*) AS count
FROM bank_accounts
WHERE (archived_at IS NULL OR archived_at = 0)
  AND LOWER(account_title) = LOWER(?)
''',
      [normalizedName],
    );

    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count({bool includeArchived = false}) async {
    final result = includeArchived
        ? _db.select('SELECT COUNT(*) AS count FROM bank_accounts')
        : _db.select(
            'SELECT COUNT(*) AS count FROM bank_accounts '
            'WHERE (archived_at IS NULL OR archived_at = 0)',
          );

    return result.first['count'] as int;
  }

  @override
  Future<void> update(BankAccount account) async {
    final localId = account.id;

    if (localId == null) {
      throw ArgumentError('Bank account id cannot be null.');
    }

    final normalizedAccountTitle = _normalizeAccountTitle(account.accountTitle);

    if (normalizedAccountTitle.isEmpty) {
      throw ArgumentError('Bank account title cannot be empty.');
    }

    final now = DateTime.now();

    _databaseService.transaction((db) {
      final existingRows = db.select(
        '''
SELECT server_uuid
FROM bank_accounts
WHERE id = ?
LIMIT 1
''',
        [localId],
      );

      if (existingRows.isEmpty) {
        throw StateError('Bank account $localId not found locally.');
      }

      _throwIfDuplicateTitle(db, normalizedAccountTitle, excludeId: localId);

      final storedServerUuid = _trimOrNull(existingRows.first['server_uuid']);
      final incomingServerUuid = _trimOrNull(account.serverUuid);
      final effectiveServerUuid = incomingServerUuid ?? storedServerUuid;

      final values = BankAccountMapper.toMap(
        BankAccount(
          id: localId,
          serverUuid: effectiveServerUuid,
          bankName: account.bankName,
          accountTitle: normalizedAccountTitle,
          accountHolder: account.accountHolder,
          accountNumber: account.accountNumber,
          cardNumber: account.cardNumber,
          iban: account.iban,
          note: account.note,
          archivedAt: account.archivedAt,
          createdAt: account.createdAt,
          updatedAt: now,
        ),
      );

      db.execute(
        '''
UPDATE bank_accounts
SET
  server_uuid = ?,
  bank_name = ?,
  account_title = ?,
  account_holder = ?,
  account_number = ?,
  card_number = ?,
  iban = ?,
  note = ?,
  archived_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [
          values['server_uuid'],
          values['bank_name'],
          values['account_title'],
          values['account_holder'],
          values['account_number'],
          values['card_number'],
          values['iban'],
          values['note'],
          values['archived_at'],
          values['updated_at'],
          localId,
        ],
      );

      _syncQueueRepository.enqueueUpdateWithMergeInDatabase(
        db,
        entityType: syncEntityTypeBankAccount,
        entityId: localId,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<void> archive(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    _databaseService.transaction((db) {
      _throwIfBankAccountMissing(db, id);

      db.execute(
        '''
UPDATE bank_accounts
SET
  archived_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [now, now, id],
      );

      _syncQueueRepository.enqueueUpdateWithMergeInDatabase(
        db,
        entityType: syncEntityTypeBankAccount,
        entityId: id,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<void> restore(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    _databaseService.transaction((db) {
      _throwIfBankAccountMissing(db, id);

      db.execute(
        '''
UPDATE bank_accounts
SET
  archived_at = NULL,
  updated_at = ?
WHERE id = ?
''',
        [now, id],
      );

      _syncQueueRepository.enqueueUpdateWithMergeInDatabase(
        db,
        entityType: syncEntityTypeBankAccount,
        entityId: id,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<void> delete(int id) async {
    _db.execute(
      '''
DELETE FROM bank_accounts
WHERE id = ?
''',
      [id],
    );
  }

  Future<void> updateServerUuid({
    required int localId,
    required String serverUuid,
  }) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('serverUuid cannot be empty.');
    }

    _db.execute(
      '''
UPDATE bank_accounts
SET
  server_uuid = ?,
  updated_at = ?
WHERE id = ?
''',
      [normalized, DateTime.now().millisecondsSinceEpoch, localId],
    );
  }

  void _throwIfBankAccountMissing(Database db, int id) {
    final rows = db.select(
      '''
SELECT id
FROM bank_accounts
WHERE id = ?
LIMIT 1
''',
      [id],
    );

    if (rows.isEmpty) {
      throw StateError('Bank account $id not found locally.');
    }
  }

  void _throwIfDuplicateTitle(
    Database db,
    String accountTitle, {
    int? excludeId,
  }) {
    final rows = excludeId == null
        ? db.select(
            '''
SELECT id
FROM bank_accounts
WHERE (archived_at IS NULL OR archived_at = 0)
  AND LOWER(account_title) = LOWER(?)
LIMIT 1
''',
            [accountTitle],
          )
        : db.select(
            '''
SELECT id
FROM bank_accounts
WHERE (archived_at IS NULL OR archived_at = 0)
  AND LOWER(account_title) = LOWER(?)
  AND id <> ?
LIMIT 1
''',
            [accountTitle, excludeId],
          );

    if (rows.isNotEmpty) {
      throw const DuplicateBankAccountNameException();
    }
  }

  String _generateUniqueServerUuid(Database db) {
    while (true) {
      final candidate = generateUuidV4();

      final rows = db.select(
        '''
SELECT id
FROM bank_accounts
WHERE server_uuid = ?
LIMIT 1
''',
        [candidate],
      );

      if (rows.isEmpty) {
        return candidate;
      }
    }
  }

  void _throwIfDuplicateServerUuid(Database db, String serverUuid) {
    final rows = db.select(
      '''
SELECT id
FROM bank_accounts
WHERE server_uuid = ?
LIMIT 1
''',
      [serverUuid],
    );

    if (rows.isNotEmpty) {
      throw StateError(
        'Bank account server UUID already exists locally: $serverUuid',
      );
    }
  }

  String? _trimOrNull(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();

    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
