import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/sqlite3.dart';

import '../database/database_service.dart';
import '../../data/repositories/local/sync_cursor_repository.dart';
import '../../data/repositories/remote/remote_cheque_repository.dart';
import 'sync_cursor.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class ChequePullMergeException implements Exception {
  const ChequePullMergeException(this.message);

  final String message;

  @override
  String toString() => 'ChequePullMergeException: $message';
}

class ChequePullBlockedByLocalChangesException
    extends ChequePullMergeException {
  const ChequePullBlockedByLocalChangesException({
    required this.localId,
    required this.serverUuid,
  }) : super(
         'Cheque pull merge blocked because local cheque '
         '$localId has unsynced work.',
       );

  final int localId;
  final String serverUuid;
}

class ChequeMergeConflictException extends ChequePullMergeException {
  const ChequeMergeConflictException(super.message);
}

class ChequePullMergeResult {
  const ChequePullMergeResult({
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

class ChequePullMergeService {
  factory ChequePullMergeService({
    required DatabaseService databaseService,
    required RemoteChequeRepository remoteRepository,
    required SyncCursorRepository cursorRepository,
    int pageLimit = RemoteChequeRepository.defaultChangesLimit,
  }) {
    return ChequePullMergeService._(
      databaseService,
      remoteRepository,
      cursorRepository,
      pageLimit,
    );
  }

  ChequePullMergeService._(
    this._databaseService,
    this._remoteRepository,
    this._cursorRepository,
    this.pageLimit,
  );

  static const int _maximumPagesPerRun = 10000;

  final DatabaseService _databaseService;
  final RemoteChequeRepository _remoteRepository;
  final SyncCursorRepository _cursorRepository;

  final int pageLimit;

  Future<ChequePullMergeResult> pullAndMerge() async {
    final cursorBefore = await _cursorRepository.getByEntityType(
      syncEntityTypeCheque,
    );

    var requestCursor = cursorBefore;
    var cursorAfter = cursorBefore;
    var pagesFetched = 0;
    var changesReceived = 0;

    final latestChangesByUuid = <String, RemoteChequeRecord>{};

    while (true) {
      if (pagesFetched >= _maximumPagesPerRun) {
        throw const ChequePullMergeException(
          'Cheque pull exceeded the maximum allowed page count.',
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
      return ChequePullMergeResult(
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
      final companyLocalIdsByChequeUuid = <String, int>{};
      final bankLocalIdsByChequeUuid = <String, int>{};

      //
      // PRE-FLIGHT
      //
      // Resolve every identity and check local pending work before changing
      // any business row. A failure therefore rolls back the whole batch.
      //
      for (final change in changes) {
        final localId = _findLocalChequeIdByServerUuid(db, change.id);

        localIdsByServerUuid[change.id] = localId;

        if (localId != null && _hasActiveLocalSyncWork(db, localId)) {
          throw ChequePullBlockedByLocalChangesException(
            localId: localId,
            serverUuid: change.id,
          );
        }

        if (localId == null && change.isDeleted) {
          continue;
        }

        companyLocalIdsByChequeUuid[change.id] = _requireDependencyLocalId(
          db,
          table: 'companies',
          dependencyName: 'Company',
          serverUuid: change.companyId,
          chequeUuid: change.id,
        );

        bankLocalIdsByChequeUuid[change.id] = _requireDependencyLocalId(
          db,
          table: 'bank_accounts',
          dependencyName: 'BankAccount',
          serverUuid: change.bankAccountId,
          chequeUuid: change.id,
        );

        _requiredDueDate(change);
        _requiredStatus(change);
        _requiredAmountRial(change);
        _decodeImageData(change.imageData);
      }

      //
      // APPLY FINAL SERVER STATE
      //
      for (final change in changes) {
        final localId = localIdsByServerUuid[change.id];

        if (localId == null && change.isDeleted) {
          tombstonesIgnored += 1;
          continue;
        }

        final companyLocalId = companyLocalIdsByChequeUuid[change.id]!;
        final bankLocalId = bankLocalIdsByChequeUuid[change.id]!;
        final dueDate = _requiredDueDate(change);
        final status = _requiredStatus(change);
        final amountRial = _requiredAmountRial(change);
        final imageData = _decodeImageData(change.imageData);

        final effectiveArchivedAt = change.deletedAt ?? change.archivedAt;
        final receiverName = localId == null
            ? null
            : _readExistingReceiverName(db, localId);

        final values = <String, Object?>{
          'server_uuid': change.id,
          'company_id': companyLocalId,
          'bank_account_id': bankLocalId,
          'cheque_number': change.chequeNumber,
          'amount_rial': amountRial,
          'issue_date': change.chequeDate.millisecondsSinceEpoch,
          'due_date': dueDate.millisecondsSinceEpoch,
          'status': status,
          'is_registered_in_sayad': (change.isRegisteredInSayad ?? false)
              ? 1
              : 0,
          'sayad_id': change.sayadId,
          'receiver_name': receiverName,
          'description': change.description,
          'image_data': imageData,
          'archived_at': effectiveArchivedAt?.millisecondsSinceEpoch,
          'delete_requested_at': null,
          'created_at': change.createdAt.millisecondsSinceEpoch,
          'updated_at': change.updatedAt.millisecondsSinceEpoch,
        };

        if (localId == null) {
          _insertRemoteCheque(db, values);
          inserted += 1;
        } else {
          _updateRemoteCheque(db, localId: localId, values: values);
          updated += 1;
        }

        if (change.isDeleted) {
          tombstonesApplied += 1;
        }
      }

      final finalCursor = cursorAfter;

      if (finalCursor != null) {
        _cursorRepository.upsertInDatabase(db, finalCursor);
      }
    });

    return ChequePullMergeResult(
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
    required RemoteChequeChangesPage page,
    required SyncCursor? requestCursor,
  }) {
    if (page.hasMore && page.nextCursor == null) {
      throw const ChequePullMergeException(
        'Cheque changes page hasMore=true but nextCursor is null.',
      );
    }

    if (page.items.isEmpty) {
      if (page.hasMore) {
        throw const ChequePullMergeException(
          'Cheque changes page is empty while hasMore=true.',
        );
      }

      return;
    }

    RemoteChequeRecord? previousItem;

    for (final item in page.items) {
      if (previousItem != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.id,
            cursorUpdatedAt: previousItem.updatedAt,
            cursorServerUuid: previousItem.id,
          )) {
        throw const ChequePullMergeException(
          'Cheque changes page is not strictly ordered by '
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
        throw const ChequePullMergeException(
          'Cheque changes page contains an item at or before '
          'the requested cursor.',
        );
      }

      previousItem = item;
    }

    final nextCursor = page.nextCursor;

    if (nextCursor == null) {
      throw const ChequePullMergeException(
        'Non-empty cheque changes page has no next cursor.',
      );
    }

    final lastItem = page.items.last;

    if (!nextCursor.updatedAt.isAtSameMomentAs(lastItem.updatedAt) ||
        nextCursor.serverUuid.trim() != lastItem.id.trim()) {
      throw const ChequePullMergeException(
        'Cheque changes nextCursor does not match the last page item.',
      );
    }

    if (requestCursor != null &&
        !_isPositionAfter(
          itemUpdatedAt: nextCursor.updatedAt,
          itemServerUuid: nextCursor.serverUuid,
          cursorUpdatedAt: requestCursor.updatedAt,
          cursorServerUuid: requestCursor.serverUuid,
        )) {
      throw const ChequePullMergeException(
        'Cheque changes cursor did not advance.',
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

  int? _findLocalChequeIdByServerUuid(Database db, String serverUuid) {
    final rows = db.select(
      '''
SELECT id
FROM cheques
WHERE server_uuid = ?
LIMIT 2
''',
      [serverUuid.trim()],
    );

    if (rows.length > 1) {
      throw ChequeMergeConflictException(
        'More than one local cheque has server UUID $serverUuid.',
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
    required String chequeUuid,
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
      throw ChequeMergeConflictException(
        '$dependencyName server UUID $serverUuid maps to multiple local rows '
        'while merging cheque $chequeUuid.',
      );
    }

    if (rows.isEmpty) {
      throw ChequeMergeConflictException(
        '$dependencyName server UUID $serverUuid is missing locally '
        'while merging cheque $chequeUuid.',
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
        syncEntityTypeCheque,
        localId,
        SyncStatus.pending.dbValue,
        SyncStatus.failed.dbValue,
        SyncStatus.processing.dbValue,
      ],
    );

    return rows.isNotEmpty;
  }

  DateTime _requiredDueDate(RemoteChequeRecord change) {
    final value = change.dueDate;

    if (value == null) {
      throw ChequeMergeConflictException(
        'Remote cheque ${change.id} has no dueDate, '
        'but the local schema requires one.',
      );
    }

    return value;
  }

  String _requiredStatus(RemoteChequeRecord change) {
    final value = change.status?.trim();

    switch (value) {
      case 'Issued':
        return 'Issued';
      case 'Registered':
        return 'Registered';
      case 'Cancelled':
        return 'Cancelled';
    }

    throw ChequeMergeConflictException(
      'Remote cheque ${change.id} has unsupported status "$value".',
    );
  }

  int _requiredAmountRial(RemoteChequeRecord change) {
    final amount = change.amount;
    final integerAmount = amount.toInt();

    if (amount != integerAmount) {
      throw ChequeMergeConflictException(
        'Remote cheque ${change.id} has a non-integer Rial amount: $amount.',
      );
    }

    return integerAmount;
  }

  Uint8List? _decodeImageData(String? value) {
    if (value == null) {
      return null;
    }

    try {
      return base64Decode(value);
    } on FormatException catch (error) {
      throw ChequeMergeConflictException(
        'Remote cheque imageData is not valid base64: $error',
      );
    }
  }

  String? _readExistingReceiverName(Database db, int localId) {
    final rows = db.select(
      '''
SELECT receiver_name
FROM cheques
WHERE id = ?
LIMIT 1
''',
      [localId],
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['receiver_name'] as String?;
  }

  void _insertRemoteCheque(Database db, Map<String, Object?> values) {
    db.execute(
      '''
INSERT INTO cheques (
  server_uuid,
  company_id,
  bank_account_id,
  cheque_number,
  amount_rial,
  issue_date,
  due_date,
  status,
  is_registered_in_sayad,
  sayad_id,
  receiver_name,
  description,
  image_data,
  archived_at,
  delete_requested_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        values['server_uuid'],
        values['company_id'],
        values['bank_account_id'],
        values['cheque_number'],
        values['amount_rial'],
        values['issue_date'],
        values['due_date'],
        values['status'],
        values['is_registered_in_sayad'],
        values['sayad_id'],
        values['receiver_name'],
        values['description'],
        values['image_data'],
        values['archived_at'],
        values['delete_requested_at'],
        values['created_at'],
        values['updated_at'],
      ],
    );
  }

  void _updateRemoteCheque(
    Database db, {
    required int localId,
    required Map<String, Object?> values,
  }) {
    db.execute(
      '''
UPDATE cheques
SET
  server_uuid = ?,
  company_id = ?,
  bank_account_id = ?,
  cheque_number = ?,
  amount_rial = ?,
  issue_date = ?,
  due_date = ?,
  status = ?,
  is_registered_in_sayad = ?,
  sayad_id = ?,
  receiver_name = ?,
  description = ?,
  image_data = ?,
  archived_at = ?,
  delete_requested_at = NULL,
  created_at = ?,
  updated_at = ?
WHERE id = ?
''',
      [
        values['server_uuid'],
        values['company_id'],
        values['bank_account_id'],
        values['cheque_number'],
        values['amount_rial'],
        values['issue_date'],
        values['due_date'],
        values['status'],
        values['is_registered_in_sayad'],
        values['sayad_id'],
        values['receiver_name'],
        values['description'],
        values['image_data'],
        values['archived_at'],
        values['created_at'],
        values['updated_at'],
        localId,
      ],
    );
  }
}
