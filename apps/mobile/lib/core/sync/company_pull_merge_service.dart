import 'package:sqlite3/sqlite3.dart';

import '../database/database_service.dart';
import '../../data/mappers/company_mapper.dart';
import '../../data/repositories/local/sync_cursor_repository.dart';
import '../../data/repositories/remote/remote_company_repository.dart';
import 'sync_cursor.dart';
import 'sync_queue_item.dart';
import 'sync_status.dart';

class CompanyPullMergeException implements Exception {
  const CompanyPullMergeException(this.message);

  final String message;

  @override
  String toString() => 'CompanyPullMergeException: $message';
}

class CompanyPullBlockedByLocalChangesException
    extends CompanyPullMergeException {
  const CompanyPullBlockedByLocalChangesException({
    required this.localId,
    required this.serverUuid,
  }) : super(
         'Company pull merge blocked because local company '
         '$localId has unsynced work.',
       );

  final int localId;
  final String serverUuid;
}

class CompanyMergeConflictException extends CompanyPullMergeException {
  const CompanyMergeConflictException(super.message);
}

class CompanyPullMergeResult {
  const CompanyPullMergeResult({
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

class CompanyPullMergeService {
  factory CompanyPullMergeService({
    required DatabaseService databaseService,
    required RemoteCompanyRepository remoteRepository,
    required SyncCursorRepository cursorRepository,
    int pageLimit = RemoteCompanyRepository.defaultChangesLimit,
  }) {
    return CompanyPullMergeService._(
      databaseService,
      remoteRepository,
      cursorRepository,
      pageLimit,
    );
  }

  CompanyPullMergeService._(
    this._databaseService,
    this._remoteRepository,
    this._cursorRepository,
    this.pageLimit,
  );

  static const int _maximumPagesPerRun = 10000;

  final DatabaseService _databaseService;
  final RemoteCompanyRepository _remoteRepository;
  final SyncCursorRepository _cursorRepository;

  final int pageLimit;

  Future<CompanyPullMergeResult> pullAndMerge() async {
    final cursorBefore = await _cursorRepository.getByEntityType(
      syncEntityTypeCompany,
    );

    var requestCursor = cursorBefore;
    var cursorAfter = cursorBefore;

    var pagesFetched = 0;
    var changesReceived = 0;

    final latestChangesByUuid = <String, RemoteCompanyChange>{};

    while (true) {
      if (pagesFetched >= _maximumPagesPerRun) {
        throw const CompanyPullMergeException(
          'Company pull exceeded the maximum allowed page count.',
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

      final nextCursor = page.nextCursor;

      if (nextCursor != null) {
        cursorAfter = nextCursor;
      }

      if (!page.hasMore) {
        break;
      }

      requestCursor = nextCursor;
    }

    if (latestChangesByUuid.isEmpty) {
      return CompanyPullMergeResult(
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
      final affectedLocalIds = <int>{};

      //
      // PRE-FLIGHT
      //
      // Nothing is changed until every incoming company has been checked.
      // This guarantees that a local unsynced edit cannot be overwritten
      // halfway through the merge.
      //
      for (final change in changes) {
        final serverUuid = change.serverUuid;

        final localId = _findLocalIdByServerUuid(db, serverUuid);

        localIdsByServerUuid[serverUuid] = localId;

        if (localId == null) {
          continue;
        }

        affectedLocalIds.add(localId);

        if (_hasActiveLocalSyncWork(db, localId)) {
          throw CompanyPullBlockedByLocalChangesException(
            localId: localId,
            serverUuid: serverUuid,
          );
        }
      }

      _validateFinalNameCollisions(
        db: db,
        changes: changes,
        localIdsByServerUuid: localIdsByServerUuid,
        affectedLocalIds: affectedLocalIds,
      );

      //
      // TEMPORARY NAMES
      //
      // Existing changed rows are temporarily moved out of the way.
      // This makes multi-record rename/swap merges safe while the whole
      // operation remains inside one SQLite transaction.
      //
      for (final change in changes) {
        final localId = localIdsByServerUuid[change.serverUuid];

        if (localId == null) {
          continue;
        }

        final temporaryName =
            '__pharmaflow_sync_tmp__'
            '${change.serverUuid.replaceAll('-', '')}__'
            '$localId';

        db.execute(
          '''
UPDATE companies
SET name = ?
WHERE id = ?
''',
          [temporaryName, localId],
        );
      }

      //
      // APPLY FINAL SERVER STATE
      //
      for (final change in changes) {
        final serverUuid = change.serverUuid;

        final localId = localIdsByServerUuid[serverUuid];

        if (localId == null && change.isDeleted) {
          //
          // A tombstone for a company that never existed on this device
          // still advances the cursor, but does not create a useless local row.
          //
          tombstonesIgnored += 1;
          continue;
        }

        final effectiveArchivedAt =
            change.deletedAt ?? change.company.archivedAt;

        final company = change.company.copyWith(
          id: localId,
          serverUuid: serverUuid,
          archivedAt: effectiveArchivedAt,
        );

        final values = CompanyMapper.toMap(company);

        if (localId == null) {
          _insertRemoteCompany(db, values);

          inserted += 1;
        } else {
          _updateRemoteCompany(db, localId: localId, values: values);

          updated += 1;
        }

        if (change.isDeleted) {
          tombstonesApplied += 1;
        }
      }

      //
      // CURSOR ADVANCE
      //
      // The cursor is written in the SAME transaction as the merge.
      // Any failure above rolls back both business data and the cursor.
      //
      final finalCursor = cursorAfter;

      if (finalCursor != null) {
        _cursorRepository.upsertInDatabase(db, finalCursor);
      }
    });

    return CompanyPullMergeResult(
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
    required RemoteCompanyChangesPage page,
    required SyncCursor? requestCursor,
  }) {
    if (page.hasMore && page.nextCursor == null) {
      throw const CompanyPullMergeException(
        'Company changes page hasMore=true but nextCursor is null.',
      );
    }

    if (page.items.isEmpty) {
      if (page.hasMore) {
        throw const CompanyPullMergeException(
          'Company changes page is empty while hasMore=true.',
        );
      }

      return;
    }

    RemoteCompanyChange? previousItem;

    for (final item in page.items) {
      if (previousItem != null) {
        if (!_isPositionAfter(
          itemUpdatedAt: item.updatedAt,
          itemServerUuid: item.serverUuid,
          cursorUpdatedAt: previousItem.updatedAt,
          cursorServerUuid: previousItem.serverUuid,
        )) {
          throw const CompanyPullMergeException(
            'Company changes page is not strictly ordered by '
            'updatedAt and server UUID.',
          );
        }
      }

      if (requestCursor != null) {
        if (!_isPositionAfter(
          itemUpdatedAt: item.updatedAt,
          itemServerUuid: item.serverUuid,
          cursorUpdatedAt: requestCursor.updatedAt,
          cursorServerUuid: requestCursor.serverUuid,
        )) {
          throw const CompanyPullMergeException(
            'Company changes page contains an item at or before '
            'the requested cursor.',
          );
        }
      }

      previousItem = item;
    }

    final nextCursor = page.nextCursor;

    if (nextCursor == null) {
      throw const CompanyPullMergeException(
        'Non-empty company changes page has no next cursor.',
      );
    }

    final lastItem = page.items.last;

    if (!nextCursor.updatedAt.isAtSameMomentAs(lastItem.updatedAt) ||
        nextCursor.serverUuid.trim() != lastItem.serverUuid.trim()) {
      throw const CompanyPullMergeException(
        'Company changes nextCursor does not match the last page item.',
      );
    }

    if (requestCursor != null &&
        !_isPositionAfter(
          itemUpdatedAt: nextCursor.updatedAt,
          itemServerUuid: nextCursor.serverUuid,
          cursorUpdatedAt: requestCursor.updatedAt,
          cursorServerUuid: requestCursor.serverUuid,
        )) {
      throw const CompanyPullMergeException(
        'Company changes cursor did not advance.',
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
FROM companies
WHERE server_uuid = ?
LIMIT 2
''',
      [serverUuid.trim()],
    );

    if (rows.length > 1) {
      throw CompanyMergeConflictException(
        'More than one local company has server UUID $serverUuid.',
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
        syncEntityTypeCompany,
        localId,
        SyncStatus.pending.dbValue,
        SyncStatus.failed.dbValue,
        SyncStatus.processing.dbValue,
      ],
    );

    return rows.isNotEmpty;
  }

  void _validateFinalNameCollisions({
    required Database db,
    required List<RemoteCompanyChange> changes,
    required Map<String, int?> localIdsByServerUuid,
    required Set<int> affectedLocalIds,
  }) {
    final incomingNames = <String, String>{};

    for (final change in changes) {
      final localId = localIdsByServerUuid[change.serverUuid];

      if (localId == null && change.isDeleted) {
        continue;
      }

      final name = change.company.name;

      final existingIncomingUuid = incomingNames[name];

      if (existingIncomingUuid != null &&
          existingIncomingUuid != change.serverUuid) {
        throw CompanyMergeConflictException(
          'Remote company batch contains duplicate final name "$name".',
        );
      }

      incomingNames[name] = change.serverUuid;

      final rows = db.select(
        '''
SELECT id, server_uuid
FROM companies
WHERE name = ?
LIMIT 2
''',
        [name],
      );

      for (final row in rows) {
        final rowId = row['id'] as int;

        if (affectedLocalIds.contains(rowId)) {
          continue;
        }

        throw CompanyMergeConflictException(
          'Remote company "${change.company.name}" conflicts with '
          'unaffected local company id $rowId.',
        );
      }
    }
  }

  void _insertRemoteCompany(Database db, Map<String, Object?> values) {
    db.execute(
      '''
INSERT INTO companies (
  server_uuid,
  name,
  national_id,
  economic_code,
  bank_name,
  account_number,
  card_number,
  sheba_number,
  notes,
  visitor_name,
  visitor_phone,
  accountant_name,
  accountant_phone,
  archived_at,
  created_at,
  updated_at
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
''',
      [
        values['server_uuid'],
        values['name'],
        values['national_id'],
        values['economic_code'],
        values['bank_name'],
        values['account_number'],
        values['card_number'],
        values['sheba_number'],
        values['notes'],
        values['visitor_name'],
        values['visitor_phone'],
        values['accountant_name'],
        values['accountant_phone'],
        values['archived_at'],
        values['created_at'],
        values['updated_at'],
      ],
    );
  }

  void _updateRemoteCompany(
    Database db, {
    required int localId,
    required Map<String, Object?> values,
  }) {
    db.execute(
      '''
UPDATE companies
SET
  server_uuid = ?,
  name = ?,
  national_id = ?,
  economic_code = ?,
  bank_name = ?,
  account_number = ?,
  card_number = ?,
  sheba_number = ?,
  notes = ?,
  visitor_name = ?,
  visitor_phone = ?,
  accountant_name = ?,
  accountant_phone = ?,
  archived_at = ?,
  created_at = ?,
  updated_at = ?
WHERE id = ?
''',
      [
        values['server_uuid'],
        values['name'],
        values['national_id'],
        values['economic_code'],
        values['bank_name'],
        values['account_number'],
        values['card_number'],
        values['sheba_number'],
        values['notes'],
        values['visitor_name'],
        values['visitor_phone'],
        values['accountant_name'],
        values['accountant_phone'],
        values['archived_at'],
        values['created_at'],
        values['updated_at'],
        localId,
      ],
    );
  }
}
