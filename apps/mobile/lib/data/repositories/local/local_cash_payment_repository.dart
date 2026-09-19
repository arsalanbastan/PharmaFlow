import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_trigger.dart';
import '../../../core/sync/sync_trigger_dispatcher.dart';
import '../../../core/utils/uuid_v4.dart';
import '../../mappers/cash_payment_mapper.dart';
import '../../models/cash_payment.dart';
import '../interfaces/cash_payment_repository.dart';
import 'sync_queue_repository.dart';

class LocalCashPaymentRepository implements CashPaymentRepository {
  LocalCashPaymentRepository(this._databaseService);

  final DatabaseService _databaseService;

  SyncQueueRepository get _syncQueueRepository =>
      SyncQueueRepository(_databaseService);

  Database get _db => _databaseService.database;

  @override
  Future<int> insert(CashPayment payment) async {
    _validate(payment);

    late final int insertedId;

    _databaseService.transaction((db) {
      final requestedServerUuid = _trimOrNull(payment.serverUuid);

      final serverUuid = requestedServerUuid ?? _generateUniqueServerUuid(db);

      _throwIfDuplicateServerUuid(db, serverUuid);

      final now = DateTime.now().toUtc();

      final entity = payment.copyWith(
        id: null,
        serverUuid: serverUuid,
        trackingNumber: _trimOrNull(payment.trackingNumber),
        description: _trimOrNull(payment.description),
        notes: _trimOrNull(payment.notes),
        updatedAt: now,
      );

      final values = CashPaymentMapper.toMap(entity);

      final statement = db.prepare('''
INSERT INTO cash_payments (
  server_uuid,
  amount_rial,
  payment_date,
  company_id,
  bank_account_id,
  payment_method,
  tracking_number,
  description,
  notes,
  archived_at,
  delete_requested_at,
  deleted_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''');

      try {
        statement.execute([
          values['server_uuid'],
          values['amount_rial'],
          values['payment_date'],
          values['company_id'],
          values['bank_account_id'],
          values['payment_method'],
          values['tracking_number'],
          values['description'],
          values['notes'],
          values['archived_at'],
          values['delete_requested_at'],
          values['deleted_at'],
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
          entityType: syncEntityTypeCashPayment,
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
  Future<void> update(CashPayment payment) async {
    final localId = payment.id;

    if (localId == null) {
      throw ArgumentError('Cash payment id cannot be null.');
    }

    _validate(payment);

    _databaseService.transaction((db) {
      final existingRows = db.select(
        '''
SELECT
  server_uuid,
  created_at
FROM cash_payments
WHERE id = ?
LIMIT 1
''',
        [localId],
      );

      if (existingRows.isEmpty) {
        throw StateError('Cash payment $localId not found locally.');
      }

      final storedServerUuid = _trimOrNull(existingRows.first['server_uuid']);
      final incomingServerUuid = _trimOrNull(payment.serverUuid);

      final effectiveServerUuid =
          incomingServerUuid ??
          storedServerUuid ??
          _generateUniqueServerUuid(db);

      _throwIfDuplicateServerUuid(db, effectiveServerUuid, excludeId: localId);

      final storedCreatedAt = _dateTimeFromDb(existingRows.first['created_at']);

      final entity = payment.copyWith(
        serverUuid: effectiveServerUuid,
        trackingNumber: _trimOrNull(payment.trackingNumber),
        description: _trimOrNull(payment.description),
        notes: _trimOrNull(payment.notes),
        createdAt: storedCreatedAt ?? payment.createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

      final values = CashPaymentMapper.toMap(entity);

      db.execute(
        '''
UPDATE cash_payments
SET
  server_uuid = ?,
  amount_rial = ?,
  payment_date = ?,
  company_id = ?,
  bank_account_id = ?,
  payment_method = ?,
  tracking_number = ?,
  description = ?,
  notes = ?,
  archived_at = ?,
  delete_requested_at = ?,
  deleted_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [
          values['server_uuid'],
          values['amount_rial'],
          values['payment_date'],
          values['company_id'],
          values['bank_account_id'],
          values['payment_method'],
          values['tracking_number'],
          values['description'],
          values['notes'],
          values['archived_at'],
          values['delete_requested_at'],
          values['deleted_at'],
          values['updated_at'],
          localId,
        ],
      );

      _syncQueueRepository.enqueueUpdateWithMergeInDatabase(
        db,
        entityType: syncEntityTypeCashPayment,
        entityId: localId,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<CashPayment?> findById(int id) async {
    final result = _db.select(
      '''
SELECT *
FROM cash_payments
WHERE id = ?
LIMIT 1
''',
      [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return CashPaymentMapper.fromMap(result.first);
  }

  @override
  Future<CashPayment?> findByServerUuid(String serverUuid) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      return null;
    }

    final result = _db.select(
      '''
SELECT *
FROM cash_payments
WHERE server_uuid = ?
LIMIT 1
''',
      [normalized],
    );

    if (result.isEmpty) {
      return null;
    }

    return CashPaymentMapper.fromMap(result.first);
  }

  @override
  Future<List<CashPayment>> getAll({
    bool includeArchived = false,
    bool includeDeleteRequested = false,
  }) async {
    return _findWhere(
      includeArchived: includeArchived,
      includeDeleteRequested: includeDeleteRequested,
    );
  }

  @override
  Future<List<CashPayment>> findByCompanyId(
    int companyId, {
    bool includeArchived = false,
    bool includeDeleteRequested = false,
  }) async {
    return _findWhere(
      companyId: companyId,
      includeArchived: includeArchived,
      includeDeleteRequested: includeDeleteRequested,
    );
  }

  @override
  Future<List<CashPayment>> findByBankAccountId(
    int bankAccountId, {
    bool includeArchived = false,
    bool includeDeleteRequested = false,
  }) async {
    return _findWhere(
      bankAccountId: bankAccountId,
      includeArchived: includeArchived,
      includeDeleteRequested: includeDeleteRequested,
    );
  }

  List<CashPayment> _findWhere({
    int? companyId,
    int? bankAccountId,
    required bool includeArchived,
    required bool includeDeleteRequested,
  }) {
    final clauses = <String>['deleted_at IS NULL'];

    final parameters = <Object?>[];

    if (!includeArchived) {
      clauses.add('archived_at IS NULL');
    }

    if (!includeDeleteRequested) {
      clauses.add('delete_requested_at IS NULL');
    }

    if (companyId != null) {
      clauses.add('company_id = ?');
      parameters.add(companyId);
    }

    if (bankAccountId != null) {
      clauses.add('bank_account_id = ?');
      parameters.add(bankAccountId);
    }

    final whereClause = clauses.join(' AND ');

    final result = _db.select('''
SELECT *
FROM cash_payments
WHERE $whereClause
ORDER BY payment_date DESC, id DESC
''', parameters);

    return result.map(CashPaymentMapper.fromMap).toList();
  }

  @override
  Future<void> archive(int id) async {
    _throwIfMissing(id);

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    _databaseService.transaction((db) {
      db.execute(
        '''
UPDATE cash_payments
SET
  archived_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [now, now, id],
      );

      _syncQueueRepository.enqueueUpdateWithMergeInDatabase(
        db,
        entityType: syncEntityTypeCashPayment,
        entityId: id,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<void> restore(int id) async {
    _throwIfMissing(id);

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    _databaseService.transaction((db) {
      db.execute(
        '''
UPDATE cash_payments
SET
  archived_at = NULL,
  updated_at = ?
WHERE id = ?
''',
        [now, id],
      );

      _syncQueueRepository.enqueueUpdateWithMergeInDatabase(
        db,
        entityType: syncEntityTypeCashPayment,
        entityId: id,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<void> requestDelete(int id) async {
    final payment = await findById(id);

    if (payment == null) {
      throw StateError('Cash payment $id not found locally.');
    }

    if (payment.deleteRequestedAt != null) {
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    _databaseService.transaction((db) {
      db.execute(
        '''
UPDATE cash_payments
SET
  delete_requested_at = ?,
  updated_at = ?
WHERE id = ?
''',
        [now, now, id],
      );

      _syncQueueRepository.enqueueDeleteWithMergeInDatabase(
        db,
        entityType: syncEntityTypeCashPayment,
        entityId: id,
      );
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  @override
  Future<void> updateServerUuid({
    required int localId,
    required String serverUuid,
  }) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('serverUuid cannot be empty.');
    }

    _throwIfDuplicateServerUuid(_db, normalized, excludeId: localId);

    _db.execute(
      '''
UPDATE cash_payments
SET
  server_uuid = ?,
  updated_at = ?
WHERE id = ?
''',
      [normalized, DateTime.now().toUtc().millisecondsSinceEpoch, localId],
    );
  }

  void _validate(CashPayment payment) {
    if (payment.amountRial <= 0) {
      throw ArgumentError('Cash payment amount must be greater than zero.');
    }

    if (payment.companyId <= 0) {
      throw ArgumentError('Cash payment companyId must be positive.');
    }

    if (payment.bankAccountId <= 0) {
      throw ArgumentError('Cash payment bankAccountId must be positive.');
    }
  }

  void _throwIfMissing(int id) {
    final result = _db.select(
      '''
SELECT id
FROM cash_payments
WHERE id = ?
LIMIT 1
''',
      [id],
    );

    if (result.isEmpty) {
      throw StateError('Cash payment $id not found locally.');
    }
  }

  String _generateUniqueServerUuid(Database db) {
    while (true) {
      final candidate = generateUuidV4();

      final result = db.select(
        '''
SELECT id
FROM cash_payments
WHERE server_uuid = ?
LIMIT 1
''',
        [candidate],
      );

      if (result.isEmpty) {
        return candidate;
      }
    }
  }

  void _throwIfDuplicateServerUuid(
    Database db,
    String serverUuid, {
    int? excludeId,
  }) {
    final rows = excludeId == null
        ? db.select(
            '''
SELECT id
FROM cash_payments
WHERE server_uuid = ?
LIMIT 1
''',
            [serverUuid],
          )
        : db.select(
            '''
SELECT id
FROM cash_payments
WHERE server_uuid = ?
  AND id <> ?
LIMIT 1
''',
            [serverUuid, excludeId],
          );

    if (rows.isNotEmpty) {
      throw StateError(
        'Cash payment server UUID already exists locally: $serverUuid',
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

  DateTime? _dateTimeFromDb(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }

    return null;
  }
}
