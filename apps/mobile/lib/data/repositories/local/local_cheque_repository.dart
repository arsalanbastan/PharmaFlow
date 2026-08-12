import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/queries/cheque_queries.dart';
import '../../../core/database/queries/sync_queue_queries.dart';
import '../../../core/sync/sync_logger.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/sync/sync_queue_item.dart';
import '../../../core/sync/sync_status.dart';
import '../../../core/sync/sync_trigger.dart';
import '../../../core/sync/sync_trigger_dispatcher.dart';
import '../../mappers/cheque_mapper.dart';
import '../../models/cheque.dart';
import '../interfaces/cheque_repository.dart';
import 'sync_queue_repository.dart';

class LocalChequeRepository implements ChequeRepository {
  LocalChequeRepository(this._databaseService);

  final DatabaseService _databaseService;
  final SyncLogger _logger = SyncLogger.instance;

  SyncQueueRepository get _syncQueueRepository =>
      SyncQueueRepository(_databaseService);

  Database get _db => _databaseService.database;

  @override
  Future<int> insert(Cheque cheque) async {
    _logger.debug('LocalChequeRepository.insert() START');

    final params = _writeParams(cheque)..remove('id');
    var insertedId = 0;

    try {
      _databaseService.transaction((db) {
        final statement = db.prepare(ChequeQueries.insert);

        try {
          try {
            _logger.debug('SQL insert into cheques started');
            statement.executeWith(
              StatementParameters.named(_namedParams(params)),
            );
            _logger.debug('SQL insert into cheques completed');
          } catch (error, stackTrace) {
            _logger.error(
              'SQL insert into cheques failed: $error',
              error: error,
              stackTrace: stackTrace,
            );
            rethrow;
          }

          insertedId =
              db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
          _logger.debug('Inserted cheque id = $insertedId');

          final syncStatement = db.prepare(SyncQueueQueries.insert);

          try {
            try {
              _logger.debug('SQL insert into sync_queue started');
              syncStatement.executeWith(
                StatementParameters.named(
                  _namedParams({
                    'entityType': syncEntityTypeCheque,
                    'entityId': insertedId,
                    'operation': SyncOperation.create.dbValue,
                    'status': SyncStatus.pending.dbValue,
                    'retryCount': 0,
                    'createdAt': DateTime.now().millisecondsSinceEpoch,
                    'lastAttemptAt': null,
                    'errorMessage': null,
                  }),
                ),
              );
              _logger.debug('SQL insert into sync_queue completed');
            } catch (error, stackTrace) {
              _logger.error(
                'SQL insert into sync_queue failed: $error',
                error: error,
                stackTrace: stackTrace,
              );
              rethrow;
            }
          } finally {
            syncStatement.dispose();
          }
        } finally {
          statement.dispose();
        }
      });
    } catch (error, stackTrace) {
      _logger.error(
        'LocalChequeRepository.insert() failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }

    _logger.debug('LocalChequeRepository.insert() END');
    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
    return insertedId;
  }

  @override
  Future<void> update(Cheque cheque) async {
    final params = _updateParams(cheque);

    try {
      _databaseService.transaction((db) {
        final statement = db.prepare(ChequeQueries.updateEditableById);

        try {
          statement.executeWith(
            StatementParameters.named(_namedParams(params)),
          );

          final changedRowCount =
              (db
                          .select('SELECT changes() AS changed_rows')
                          .first['changed_rows']
                      as num)
                  .toInt();

          if (changedRowCount == 0) {
            throw StateError(
              'Cheque update affected 0 rows for id ${cheque.id}',
            );
          }
        } finally {
          statement.dispose();
        }
      });

      await _syncQueueRepository.enqueueUpdateWithMerge(
        entityType: syncEntityTypeCheque,
        entityId: cheque.id,
      );

      SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
    } catch (error, stackTrace) {
      _logger.error(
        'LocalChequeRepository.update() failed.',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> requestDelete(int id) async {
    final cheque = await findById(id);
    if (cheque == null) {
      throw StateError('Cheque $id not found for delete request.');
    }

    if (cheque.deleteRequestedAt != null) {
      return;
    }

    final now = DateTime.now();

    _databaseService.transaction((db) {
      final deleteStatement = db.prepare(ChequeQueries.markDeleteRequestedById);

      try {
        deleteStatement.executeWith(
          StatementParameters.named(
            _namedParams({
              'id': id,
              'archivedAt': now.millisecondsSinceEpoch,
              'deleteRequestedAt': now.millisecondsSinceEpoch,
              'updatedAt': now.millisecondsSinceEpoch,
            }),
          ),
        );

        // Coalesce DELETE with any existing active queue item for this cheque.
        final existingStmt = db.prepare(
          SyncQueueQueries.findLatestActiveByEntity,
        );
        late final ResultSet existingRows;
        try {
          existingRows = existingStmt.selectWith(
            StatementParameters.named({
              ':entityType': syncEntityTypeCheque,
              ':entityId': id,
              ':pendingStatus': SyncStatus.pending.dbValue,
              ':failedStatus': SyncStatus.failed.dbValue,
              ':processingStatus': SyncStatus.processing.dbValue,
            }),
          );
        } finally {
          existingStmt.dispose();
        }

        if (existingRows.isNotEmpty) {
          final existing = SyncQueueItem.fromDbMap(existingRows.first);
          if (existing.operation == SyncOperation.delete) {
            // Duplicate DELETE: skip.
            return;
          }
          if (existing.operation == SyncOperation.create) {
            // CREATE was never synced remotely: cancel it; no remote DELETE needed.
            final cancelStmt = db.prepare(SyncQueueQueries.deleteById);
            try {
              cancelStmt.executeWith(
                StatementParameters.named({':id': existing.id}),
              );
            } finally {
              cancelStmt.dispose();
            }
            return;
          }
          if (existing.operation == SyncOperation.update &&
              existing.id != null) {
            // DELETE supersedes UPDATE: remove the pending UPDATE first.
            final cancelStmt = db.prepare(SyncQueueQueries.deleteById);
            try {
              cancelStmt.executeWith(
                StatementParameters.named({':id': existing.id}),
              );
            } finally {
              cancelStmt.dispose();
            }
          }
        }

        // Insert the DELETE entry.
        final syncStatement = db.prepare(SyncQueueQueries.insert);

        try {
          syncStatement.executeWith(
            StatementParameters.named(
              _namedParams({
                'entityType': syncEntityTypeCheque,
                'entityId': id,
                'operation': SyncOperation.delete.dbValue,
                'status': SyncStatus.pending.dbValue,
                'retryCount': 0,
                'createdAt': now.millisecondsSinceEpoch,
                'lastAttemptAt': null,
                'errorMessage': null,
              }),
            ),
          );
        } finally {
          syncStatement.dispose();
        }
      } finally {
        deleteStatement.dispose();
      }
    });

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  Future<void> hardDelete(int id) async {
    final statement = _db.prepare(ChequeQueries.deleteById);

    try {
      statement.executeWith(
        StatementParameters.named(_namedParams({'id': id})),
      );
    } finally {
      statement.dispose();
    }

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  Future<void> updateServerUuid({
    required int id,
    required String serverUuid,
  }) async {
    final normalized = serverUuid.trim();

    if (normalized.isEmpty) {
      throw ArgumentError('serverUuid cannot be empty.');
    }

    final statement = _db.prepare(ChequeQueries.updateServerUuidById);

    try {
      statement.executeWith(
        StatementParameters.named(
          _namedParams({
            'id': id,
            'serverUuid': normalized,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          }),
        ),
      );
    } finally {
      statement.dispose();
    }

    SyncTriggerDispatcher.instance.request(SyncTrigger.entityChanged);
  }

  Map<String, Object?> _updateParams(Cheque cheque) {
    final params = {
      'id': cheque.id,
      'chequeNumber': cheque.chequeNumber,
      'amountRial': cheque.amountRial,
      'issueDate': cheque.issueDate.millisecondsSinceEpoch,
      'dueDate': cheque.dueDate.millisecondsSinceEpoch,
      'status': _statusToDb(cheque.status),
      'isRegisteredInSayad': cheque.isRegisteredInSayad ? 1 : 0,
      'sayadId': cheque.sayadId,
      'receiverName': cheque.receiverName,
      'description': cheque.description,
      'imageData': cheque.imageData,
      'archivedAt': cheque.archivedAt?.millisecondsSinceEpoch,
      'updatedAt': cheque.updatedAt.millisecondsSinceEpoch,
    };
    return params;
  }

  Map<String, Object?> _writeParams(Cheque cheque) {
    return {
      'id': cheque.id,
      'serverUuid': cheque.serverUuid,
      'companyId': cheque.companyId,
      'bankAccountId': cheque.bankAccountId,
      'chequeNumber': cheque.chequeNumber,
      'amountRial': cheque.amountRial,
      'issueDate': cheque.issueDate.millisecondsSinceEpoch,
      'dueDate': cheque.dueDate.millisecondsSinceEpoch,
      'status': _statusToDb(cheque.status),
      'isRegisteredInSayad': cheque.isRegisteredInSayad ? 1 : 0,
      'sayadId': cheque.sayadId,
      'receiverName': cheque.receiverName,
      'description': cheque.description,
      'imageData': cheque.imageData,
      'archivedAt': cheque.archivedAt?.millisecondsSinceEpoch,
      'deleteRequestedAt': cheque.deleteRequestedAt?.millisecondsSinceEpoch,
      'createdAt': cheque.createdAt.millisecondsSinceEpoch,
      'updatedAt': cheque.updatedAt.millisecondsSinceEpoch,
    };
  }

  String _statusToDb(ChequeStatus status) {
    switch (status) {
      case ChequeStatus.issued:
        return 'Issued';
      case ChequeStatus.registered:
        return 'Registered';
      case ChequeStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  Future<Cheque?> findById(int id) async {
    final result = _select(ChequeQueries.findById, {'id': id});

    if (result.isEmpty) {
      return null;
    }

    return ChequeMapper.fromMap(result.first);
  }

  @override
  Future<List<Cheque>> getActiveCheques() async {
    final result = _select(ChequeQueries.findActive, const {});
    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> getAll({
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findList,
      _listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
      ),
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findByDateRange({
    DateTime? fromDate,
    DateTime? toDate,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findList,
      _listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
        fromDate: fromDate,
        toDate: toDate,
      ),
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findByCompanyId(
    int companyId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(ChequeQueries.findByCompanyId, {
      ..._listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
        fromDate: fromDate,
        toDate: toDate,
        search: search,
      ),
      'companyId': companyId,
    });

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findByBankAccountId(
    int bankAccountId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(ChequeQueries.findByBankAccountId, {
      ..._listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
        fromDate: fromDate,
        toDate: toDate,
        search: search,
      ),
      'bankAccountId': bankAccountId,
    });

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> search(
    String query, {
    DateTime? fromDate,
    DateTime? toDate,
    int? companyId,
    int? bankAccountId,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findList,
      _listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
        fromDate: fromDate,
        toDate: toDate,
        search: query,
        companyId: companyId,
        bankAccountId: bankAccountId,
      ),
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findDuplicatesByBankAccountAndChequeNumber({
    required int bankAccountId,
    required String chequeNumber,
  }) async {
    final result = _select(
      ChequeQueries.findDuplicatesByBankAccountAndChequeNumber,
      {'bankAccountId': bankAccountId, 'chequeNumber': chequeNumber},
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<String?> suggestLatestChequeNumber(int bankAccountId) async {
    final result = _select(
      ChequeQueries.findLatestChequeNumberByBankAccountId,
      {'bankAccountId': bankAccountId},
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['cheque_number'] as String?;
  }

  @override
  Future<int> count({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int? companyId,
    int? bankAccountId,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final sql = companyId != null
        ? ChequeQueries.countByCompanyId
        : bankAccountId != null
        ? ChequeQueries.countByBankAccountId
        : ChequeQueries.countList;

    final params = _listParams(
      includeArchived: includeArchived,
      includeCancelled: includeCancelled,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      companyId: companyId,
      bankAccountId: bankAccountId,
    );

    final result = _select(sql, params);
    return result.first['total'] as int;
  }

  ResultSet _select(String sql, Map<String, Object?> params) {
    final statement = _db.prepare(sql);

    try {
      return statement.selectWith(
        StatementParameters.named(_namedParams(params)),
      );
    } finally {
      statement.dispose();
    }
  }

  Map<String, Object?> _namedParams(Map<String, Object?> params) {
    final named = <String, Object?>{};

    for (final entry in params.entries) {
      named[':${entry.key}'] = entry.value;
    }

    return named;
  }

  Map<String, Object?> _listParams({
    required bool includeArchived,
    required bool includeCancelled,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int? companyId,
    int? bankAccountId,
  }) {
    return {
      'includeArchived': includeArchived ? 1 : 0,
      'includeCancelled': includeCancelled ? 1 : 0,
      'fromDate': fromDate?.millisecondsSinceEpoch,
      'toDate': toDate?.millisecondsSinceEpoch,
      'search': search,
      'companyId': companyId,
      'bankAccountId': bankAccountId,
    };
  }
}
