import 'package:sqlite3/sqlite3.dart';

import '../database/database_service.dart';
import '../../data/mappers/cash_payment_mapper.dart';
import '../../data/repositories/local/sync_cursor_repository.dart';
import '../../data/repositories/remote/remote_cash_payment_repository.dart';
import 'sync_cursor.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class CashPaymentPullMergeException implements Exception {
  const CashPaymentPullMergeException(this.message);

  final String message;

  @override
  String toString() => 'CashPaymentPullMergeException: $message';
}

class CashPaymentPullBlockedByLocalChangesException
    extends CashPaymentPullMergeException {
  const CashPaymentPullBlockedByLocalChangesException({
    required this.localId,
    required this.serverUuid,
  }) : super(
         'Cash payment pull merge blocked because local cash payment '
         '$localId has unsynced work.',
       );

  final int localId;
  final String serverUuid;
}

class CashPaymentMergeConflictException extends CashPaymentPullMergeException {
  const CashPaymentMergeConflictException(super.message);
}

class CashPaymentPullMergeResult {
  const CashPaymentPullMergeResult({
    required this.pagesFetched,
    required this.changesReceived,
    required this.uniqueChanges,
    required this.inserted,
    required this.updated,
    required this.tombstonesApplied,
    required this.tombstonesIgnored,
    required this.cursorBefore,
    required this.cursorAfter,
  });

  final int pagesFetched;
  final int changesReceived;
  final int uniqueChanges;
  final int inserted;
  final int updated;
  final int tombstonesApplied;
  final int tombstonesIgnored;
  final SyncCursor? cursorBefore;
  final SyncCursor? cursorAfter;

  bool get changedLocalData =>
      inserted > 0 || updated > 0 || tombstonesApplied > 0;
}

class CashPaymentPullMergeService {
  factory CashPaymentPullMergeService({
    required DatabaseService databaseService,
    required RemoteCashPaymentRepository remoteRepository,
    required SyncCursorRepository cursorRepository,
    int pageLimit = RemoteCashPaymentRepository.defaultChangesLimit,
  }) {
    return CashPaymentPullMergeService._(
      databaseService,
      remoteRepository,
      cursorRepository,
      pageLimit,
    );
  }

  CashPaymentPullMergeService._(
    this._databaseService,
    this._remoteRepository,
    this._cursorRepository,
    this.pageLimit,
  );

  static const int _maximumPagesPerRun = 10000;

  final DatabaseService _databaseService;

  final RemoteCashPaymentRepository _remoteRepository;

  final SyncCursorRepository _cursorRepository;

  final int pageLimit;

  Future<CashPaymentPullMergeResult> pullAndMerge() async {
    final cursorBefore = await _cursorRepository.getByEntityType(
      syncEntityTypeCashPayment,
    );

    var requestCursor = cursorBefore;

    var cursorAfter = cursorBefore;

    var pagesFetched = 0;
    var changesReceived = 0;

    final latestChangesByUuid = <String, RemoteCashPaymentRecord>{};

    while (true) {
      if (pagesFetched >= _maximumPagesPerRun) {
        throw const CashPaymentPullMergeException(
          'Cash payment pull exceeded the maximum allowed page count.',
        );
      }

      final page = await _remoteRepository.getChanges(
        cursor: requestCursor,
        limit: pageLimit,
      );

      pagesFetched += 1;
      changesReceived += page.items.length;

      _validatePage(page: page, requestCursor: requestCursor);

      for (final change in page.items) {
        latestChangesByUuid[change.id] = change;
      }

      if (page.nextCursor != null) {
        cursorAfter = page.nextCursor;
      }

      if (!page.hasMore) {
        break;
      }

      requestCursor = page.nextCursor;
    }

    if (latestChangesByUuid.isEmpty) {
      return CashPaymentPullMergeResult(
        pagesFetched: pagesFetched,
        changesReceived: changesReceived,
        uniqueChanges: 0,
        inserted: 0,
        updated: 0,
        tombstonesApplied: 0,
        tombstonesIgnored: 0,
        cursorBefore: cursorBefore,
        cursorAfter: cursorAfter,
      );
    }

    var inserted = 0;
    var updated = 0;
    var tombstonesApplied = 0;
    var tombstonesIgnored = 0;

    final changes = latestChangesByUuid.values.toList(growable: false);

    _databaseService.transaction((db) {
      final localIdsByServerUuid = <String, int?>{};

      final companyLocalIds = <String, int>{};

      final bankLocalIds = <String, int>{};

      // ----------------------------------------------------
      // PRE-FLIGHT
      // ----------------------------------------------------

      for (final change in changes) {
        final localId = _findLocalCashPaymentIdByServerUuid(db, change.id);

        localIdsByServerUuid[change.id] = localId;

        if (localId != null && _hasActiveLocalSyncWork(db, localId)) {
          throw CashPaymentPullBlockedByLocalChangesException(
            localId: localId,
            serverUuid: change.id,
          );
        }

        if (localId == null && change.isDeleted) {
          continue;
        }

        companyLocalIds[change.id] = _requireDependencyLocalId(
          db,
          table: 'companies',
          dependencyName: 'Company',
          serverUuid: change.companyId,
          paymentUuid: change.id,
        );

        bankLocalIds[change.id] = _requireDependencyLocalId(
          db,
          table: 'bank_accounts',
          dependencyName: 'BankAccount',
          serverUuid: change.bankAccountId,
          paymentUuid: change.id,
        );
      }

      // ----------------------------------------------------
      // APPLY FINAL SERVER STATE
      // ----------------------------------------------------

      for (final change in changes) {
        final localId = localIdsByServerUuid[change.id];

        if (localId == null && change.isDeleted) {
          tombstonesIgnored += 1;
          continue;
        }

        final companyLocalId = companyLocalIds[change.id]!;

        final bankLocalId = bankLocalIds[change.id]!;

        final values = <String, Object?>{
          'server_uuid': change.id,

          'amount_rial': change.amountRial,

          'payment_date': change.paymentDate.millisecondsSinceEpoch,

          'company_id': companyLocalId,

          'bank_account_id': bankLocalId,

          'payment_method': CashPaymentMapper.paymentMethodToWireValue(
            change.paymentMethod,
          ),

          'tracking_number': change.trackingNumber,

          'description': change.description,

          'notes': change.notes,

          'archived_at': change.archivedAt?.millisecondsSinceEpoch,

          'delete_requested_at': null,

          'deleted_at': change.deletedAt?.millisecondsSinceEpoch,

          'created_at': change.createdAt.millisecondsSinceEpoch,

          'updated_at': change.updatedAt.millisecondsSinceEpoch,
        };

        if (localId == null) {
          _insertRemoteCashPayment(db, values);

          inserted += 1;
        } else {
          _updateRemoteCashPayment(db, localId: localId, values: values);

          updated += 1;
        }

        if (change.isDeleted) {
          tombstonesApplied += 1;
        }
      }

      // ----------------------------------------------------
      // CURSOR ADVANCE IN SAME TRANSACTION
      // ----------------------------------------------------

      final finalCursor = cursorAfter;

      if (finalCursor != null) {
        _cursorRepository.upsertInDatabase(db, finalCursor);
      }
    });

    return CashPaymentPullMergeResult(
      pagesFetched: pagesFetched,
      changesReceived: changesReceived,
      uniqueChanges: changes.length,
      inserted: inserted,
      updated: updated,
      tombstonesApplied: tombstonesApplied,
      tombstonesIgnored: tombstonesIgnored,
      cursorBefore: cursorBefore,
      cursorAfter: cursorAfter,
    );
  }

  void _validatePage({
    required RemoteCashPaymentChangesPage page,
    required SyncCursor? requestCursor,
  }) {
    if (page.hasMore && page.nextCursor == null) {
      throw const CashPaymentPullMergeException(
        'Cash payment changes page hasMore=true but nextCursor is null.',
      );
    }

    if (page.items.isEmpty) {
      if (page.hasMore) {
        throw const CashPaymentPullMergeException(
          'Cash payment changes page is empty while hasMore=true.',
        );
      }

      return;
    }

    RemoteCashPaymentRecord? previousItem;

    for (final item in page.items) {
      if (previousItem != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.id,
            cursorUpdatedAt: previousItem.updatedAt,
            cursorServerUuid: previousItem.id,
          )) {
        throw const CashPaymentPullMergeException(
          'Cash payment changes page is not strictly ordered by '
          'updatedAt and server UUID.',
        );
      }

      if (requestCursor != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.id,
            cursorUpdatedAt: requestCursor.updatedAt,
            cursorServerUuid: requestCursor.serverUuid,
          )) {
        throw const CashPaymentPullMergeException(
          'Cash payment changes page contains an item at or before '
          'the requested cursor.',
        );
      }

      previousItem = item;
    }

    final nextCursor = page.nextCursor;

    if (nextCursor == null) {
      throw const CashPaymentPullMergeException(
        'Non-empty cash payment changes page has no next cursor.',
      );
    }

    final lastItem = page.items.last;

    if (!nextCursor.updatedAt.isAtSameMomentAs(lastItem.updatedAt) ||
        nextCursor.serverUuid.trim() != lastItem.id.trim()) {
      throw const CashPaymentPullMergeException(
        'Cash payment changes nextCursor does not match the last page item.',
      );
    }

    if (requestCursor != null &&
        !_isPositionAfter(
          itemUpdatedAt: nextCursor.updatedAt,
          itemServerUuid: nextCursor.serverUuid,
          cursorUpdatedAt: requestCursor.updatedAt,
          cursorServerUuid: requestCursor.serverUuid,
        )) {
      throw const CashPaymentPullMergeException(
        'Cash payment changes cursor did not advance.',
      );
    }
  }

  bool _isPositionAfter({
    required DateTime itemUpdatedAt,
    required String itemServerUuid,
    required DateTime cursorUpdatedAt,
    required String cursorServerUuid,
  }) {
    final itemTime = itemUpdatedAt.toUtc();

    final cursorTime = cursorUpdatedAt.toUtc();

    if (itemTime.isAfter(cursorTime)) {
      return true;
    }

    if (itemTime.isBefore(cursorTime)) {
      return false;
    }

    return itemServerUuid.trim().compareTo(cursorServerUuid.trim()) > 0;
  }

  int? _findLocalCashPaymentIdByServerUuid(Database db, String serverUuid) {
    final rows = db.select(
      '''
SELECT id
FROM cash_payments
WHERE server_uuid = ?
LIMIT 2
''',
      [serverUuid.trim()],
    );

    if (rows.length > 1) {
      throw CashPaymentMergeConflictException(
        'More than one local cash payment has server UUID $serverUuid.',
      );
    }

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['id'] as int;
  }

  int _requireDependencyLocalId(
    Database db, {
    required String table,
    required String dependencyName,
    required String serverUuid,
    required String paymentUuid,
  }) {
    final rows = db.select(
      '''
SELECT id
FROM $table
WHERE server_uuid = ?
LIMIT 2
''',
      [serverUuid.trim()],
    );

    if (rows.length > 1) {
      throw CashPaymentMergeConflictException(
        '$dependencyName server UUID $serverUuid maps to multiple local rows '
        'while merging cash payment $paymentUuid.',
      );
    }

    if (rows.isEmpty) {
      throw CashPaymentMergeConflictException(
        '$dependencyName server UUID $serverUuid is missing locally '
        'while merging cash payment $paymentUuid.',
      );
    }

    return rows.first['id'] as int;
  }

  bool _hasActiveLocalSyncWork(Database db, int localId) {
    final rows = db.select(
      '''
SELECT id
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
  AND status IN (?, ?, ?)
LIMIT 1
''',
      [
        syncEntityTypeCashPayment,
        localId,
        SyncStatus.pending.dbValue,
        SyncStatus.failed.dbValue,
        SyncStatus.processing.dbValue,
      ],
    );

    return rows.isNotEmpty;
  }

  void _insertRemoteCashPayment(Database db, Map<String, Object?> values) {
    db.execute(
      '''
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
        values['created_at'],
        values['updated_at'],
      ],
    );
  }

  void _updateRemoteCashPayment(
    Database db, {
    required int localId,
    required Map<String, Object?> values,
  }) {
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
  delete_requested_at = NULL,
  deleted_at = ?,
  created_at = ?,
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
        values['deleted_at'],
        values['created_at'],
        values['updated_at'],
        localId,
      ],
    );
  }
}
