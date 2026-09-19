import 'package:sqlite3/sqlite3.dart';

import '../database/database_service.dart';
import '../../data/mappers/bank_account_mapper.dart';
import '../../data/repositories/local/sync_cursor_repository.dart';
import '../../data/repositories/remote/remote_bank_accounts_repository.dart';
import 'sync_cursor.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class BankAccountPullMergeException implements Exception {
  const BankAccountPullMergeException(this.message);

  final String message;

  @override
  String toString() => 'BankAccountPullMergeException: $message';
}

class BankAccountPullBlockedByLocalChangesException
    extends BankAccountPullMergeException {
  const BankAccountPullBlockedByLocalChangesException({
    required this.localId,
    required this.serverUuid,
  }) : super(
         'Bank account pull merge blocked because local bank account '
         '$localId has unsynced work.',
       );

  final int localId;
  final String serverUuid;
}

class BankAccountMergeConflictException extends BankAccountPullMergeException {
  const BankAccountMergeConflictException(super.message);
}

class BankAccountPullMergeResult {
  const BankAccountPullMergeResult({
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

class BankAccountPullMergeService {
  factory BankAccountPullMergeService({
    required DatabaseService databaseService,
    required RemoteBankAccountsRepository remoteRepository,
    required SyncCursorRepository cursorRepository,
    int pageLimit = RemoteBankAccountsRepository.defaultChangesLimit,
  }) {
    return BankAccountPullMergeService._(
      databaseService,
      remoteRepository,
      cursorRepository,
      pageLimit,
    );
  }

  BankAccountPullMergeService._(
    this._databaseService,
    this._remoteRepository,
    this._cursorRepository,
    this.pageLimit,
  );

  static const int _maximumPagesPerRun = 10000;

  final DatabaseService _databaseService;
  final RemoteBankAccountsRepository _remoteRepository;
  final SyncCursorRepository _cursorRepository;

  final int pageLimit;

  Future<BankAccountPullMergeResult> pullAndMerge() async {
    final cursorBefore = await _cursorRepository.getByEntityType(
      syncEntityTypeBankAccount,
    );

    var requestCursor = cursorBefore;
    var cursorAfter = cursorBefore;
    var pagesFetched = 0;
    var changesReceived = 0;

    final latestChangesByUuid = <String, RemoteBankAccountChange>{};

    while (true) {
      if (pagesFetched >= _maximumPagesPerRun) {
        throw const BankAccountPullMergeException(
          'Bank account pull exceeded the maximum allowed page count.',
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
        latestChangesByUuid[change.serverUuid] = change;
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
      return BankAccountPullMergeResult(
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

      for (final change in changes) {
        final localId = _findLocalIdByServerUuid(db, change.serverUuid);

        localIdsByServerUuid[change.serverUuid] = localId;

        if (localId != null && _hasActiveLocalSyncWork(db, localId)) {
          throw BankAccountPullBlockedByLocalChangesException(
            localId: localId,
            serverUuid: change.serverUuid,
          );
        }
      }

      for (final change in changes) {
        final serverUuid = change.serverUuid;
        final localId = localIdsByServerUuid[serverUuid];

        if (localId == null && change.isDeleted) {
          tombstonesIgnored += 1;
          continue;
        }

        final effectiveArchivedAt =
            change.deletedAt ?? change.account.archivedAt;

        final values = BankAccountMapper.toMap(change.account);
        values['id'] = localId;
        values['server_uuid'] = serverUuid;
        values['archived_at'] = effectiveArchivedAt?.millisecondsSinceEpoch;

        if (localId == null) {
          _insertRemoteBankAccount(db, values);
          inserted += 1;
        } else {
          _updateRemoteBankAccount(db, localId: localId, values: values);
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

    return BankAccountPullMergeResult(
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
    required RemoteBankAccountChangesPage page,
    required SyncCursor? requestCursor,
  }) {
    if (page.hasMore && page.nextCursor == null) {
      throw const BankAccountPullMergeException(
        'Bank account changes page hasMore=true but nextCursor is null.',
      );
    }

    if (page.items.isEmpty) {
      if (page.hasMore) {
        throw const BankAccountPullMergeException(
          'Bank account changes page is empty while hasMore=true.',
        );
      }

      return;
    }

    RemoteBankAccountChange? previousItem;

    for (final item in page.items) {
      if (previousItem != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.serverUuid,
            cursorUpdatedAt: previousItem.updatedAt,
            cursorServerUuid: previousItem.serverUuid,
          )) {
        throw const BankAccountPullMergeException(
          'Bank account changes page is not strictly ordered by '
          'updatedAt and server UUID.',
        );
      }

      if (requestCursor != null &&
          !_isPositionAfter(
            itemUpdatedAt: item.updatedAt,
            itemServerUuid: item.serverUuid,
            cursorUpdatedAt: requestCursor.updatedAt,
            cursorServerUuid: requestCursor.serverUuid,
          )) {
        throw const BankAccountPullMergeException(
          'Bank account changes page contains an item at or before '
          'the requested cursor.',
        );
      }

      previousItem = item;
    }

    final nextCursor = page.nextCursor;

    if (nextCursor == null) {
      throw const BankAccountPullMergeException(
        'Non-empty bank account changes page has no next cursor.',
      );
    }

    final lastItem = page.items.last;

    if (!nextCursor.updatedAt.isAtSameMomentAs(lastItem.updatedAt) ||
        nextCursor.serverUuid.trim() != lastItem.serverUuid.trim()) {
      throw const BankAccountPullMergeException(
        'Bank account changes nextCursor does not match the last page item.',
      );
    }

    if (requestCursor != null &&
        !_isPositionAfter(
          itemUpdatedAt: nextCursor.updatedAt,
          itemServerUuid: nextCursor.serverUuid,
          cursorUpdatedAt: requestCursor.updatedAt,
          cursorServerUuid: requestCursor.serverUuid,
        )) {
      throw const BankAccountPullMergeException(
        'Bank account changes cursor did not advance.',
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

  int? _findLocalIdByServerUuid(Database db, String serverUuid) {
    final rows = db.select(
      '''
SELECT id
FROM bank_accounts
WHERE server_uuid = ?
LIMIT 2
''',
      [serverUuid.trim()],
    );

    if (rows.length > 1) {
      throw BankAccountMergeConflictException(
        'More than one local bank account has server UUID $serverUuid.',
      );
    }

    if (rows.isEmpty) {
      return null;
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
        syncEntityTypeBankAccount,
        localId,
        SyncStatus.pending.dbValue,
        SyncStatus.failed.dbValue,
        SyncStatus.processing.dbValue,
      ],
    );

    return rows.isNotEmpty;
  }

  void _insertRemoteBankAccount(Database db, Map<String, Object?> values) {
    db.execute(
      '''
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
        values['created_at'],
        values['updated_at'],
      ],
    );
  }

  void _updateRemoteBankAccount(
    Database db, {
    required int localId,
    required Map<String, Object?> values,
  }) {
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
  created_at = ?,
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
        values['created_at'],
        values['updated_at'],
        localId,
      ],
    );
  }
}
