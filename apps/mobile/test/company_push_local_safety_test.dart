import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:pharmaflow/core/database/database_service.dart';
import 'package:pharmaflow/core/database/migration_manager.dart';
import 'package:pharmaflow/core/sync/sync_operation.dart';
import 'package:pharmaflow/core/sync/sync_queue_item.dart';
import 'package:pharmaflow/core/sync/sync_status.dart';
import 'package:pharmaflow/data/models/company.dart';
import 'package:pharmaflow/data/repositories/local/local_company_repository.dart';
import 'package:pharmaflow/data/repositories/local/sync_queue_repository.dart';

final RegExp _uuidV4Pattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

Company _newCompany(String name) {
  final now = DateTime.now();

  return Company(
    id: null,
    serverUuid: null,
    name: name,
    nationalId: null,
    economicCode: null,
    notes: null,
    visitorName: null,
    visitorPhone: null,
    accountantName: null,
    accountantPhone: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

List<SyncQueueItem> _companyQueueItems(
  SyncQueueRepository repository,
  int companyId,
) {
  final rows = DatabaseService.instance.database.select(
    '''
SELECT *
FROM sync_queue
WHERE entityType = ?
  AND entityId = ?
ORDER BY id ASC
''',
    <Object?>[syncEntityTypeCompany, companyId],
  );

  return rows
      .map((row) => SyncQueueItem.fromDbMap(row))
      .toList(growable: false);
}

void main() {
  late Database db;
  late LocalCompanyRepository companyRepository;
  late SyncQueueRepository queueRepository;

  setUp(() {
    db = sqlite3.openInMemory();
    MigrationManager.migrate(db);
    DatabaseService.instance.injectDatabaseForTesting(db);

    companyRepository = LocalCompanyRepository(DatabaseService.instance);
    queueRepository = SyncQueueRepository(DatabaseService.instance);
  });

  tearDown(() {
    db.dispose();
  });

  test(
    'Company INSERT generates UUID and atomically creates one pending CREATE queue item',
    () async {
      final companyId = await companyRepository.insert(
        _newCompany('Local Create Test'),
      );

      final company = await companyRepository.findById(companyId);
      final queueItems = _companyQueueItems(queueRepository, companyId);

      expect(company, isNotNull);
      expect(company!.serverUuid, isNotNull);
      expect(_uuidV4Pattern.hasMatch(company.serverUuid!), isTrue);

      expect(queueItems.length, equals(1));
      expect(queueItems.single.operation, SyncOperation.create);
      expect(queueItems.single.status, SyncStatus.pending);
    },
  );

  test(
    'edit before first sync keeps CREATE and sends latest local snapshot later',
    () async {
      final companyId = await companyRepository.insert(
        _newCompany('Before Edit'),
      );

      final original = await companyRepository.findById(companyId);
      expect(original, isNotNull);

      await companyRepository.update(
        original!.copyWith(name: 'After Edit', notes: 'latest-local-snapshot'),
      );

      final updated = await companyRepository.findById(companyId);
      final queueItems = _companyQueueItems(queueRepository, companyId);

      expect(updated!.name, equals('After Edit'));
      expect(updated.notes, equals('latest-local-snapshot'));
      expect(updated.serverUuid, equals(original.serverUuid));

      expect(queueItems.length, equals(1));
      expect(queueItems.single.operation, SyncOperation.create);
      expect(queueItems.single.status, SyncStatus.pending);
    },
  );

  test(
    'archive before first sync keeps CREATE and preserves archived snapshot',
    () async {
      final companyId = await companyRepository.insert(
        _newCompany('Archive Before Sync'),
      );

      await companyRepository.archive(companyId);

      final company = await companyRepository.findById(companyId);
      final queueItems = _companyQueueItems(queueRepository, companyId);

      expect(company, isNotNull);
      expect(company!.archivedAt, isNotNull);

      expect(queueItems.length, equals(1));
      expect(queueItems.single.operation, SyncOperation.create);
      expect(queueItems.single.status, SyncStatus.pending);
    },
  );

  test(
    'restore before first sync keeps CREATE and restores archivedAt to null',
    () async {
      final companyId = await companyRepository.insert(
        _newCompany('Restore Before Sync'),
      );

      await companyRepository.archive(companyId);
      await companyRepository.restore(companyId);

      final company = await companyRepository.findById(companyId);
      final queueItems = _companyQueueItems(queueRepository, companyId);

      expect(company, isNotNull);
      expect(company!.archivedAt, isNull);

      expect(queueItems.length, equals(1));
      expect(queueItems.single.operation, SyncOperation.create);
      expect(queueItems.single.status, SyncStatus.pending);
    },
  );

  test(
    'mutation while CREATE is PROCESSING creates a follow-up pending UPDATE',
    () async {
      final companyId = await companyRepository.insert(
        _newCompany('Create Processing'),
      );

      var queueItems = _companyQueueItems(queueRepository, companyId);
      final createQueueId = queueItems.single.id!;

      await queueRepository.markProcessing(createQueueId);

      final company = await companyRepository.findById(companyId);
      await companyRepository.update(
        company!.copyWith(notes: 'changed-while-create-in-flight'),
      );

      queueItems = _companyQueueItems(queueRepository, companyId);

      expect(queueItems.length, equals(2));
      expect(queueItems[0].operation, SyncOperation.create);
      expect(queueItems[0].status, SyncStatus.processing);
      expect(queueItems[1].operation, SyncOperation.update);
      expect(queueItems[1].status, SyncStatus.pending);
    },
  );

  test(
    'mutation while UPDATE is PROCESSING creates a follow-up pending UPDATE',
    () async {
      final companyId = await companyRepository.insert(
        _newCompany('Update Processing'),
      );

      var queueItems = _companyQueueItems(queueRepository, companyId);
      final createQueueId = queueItems.single.id!;
      await queueRepository.markSynced(createQueueId);

      final company = await companyRepository.findById(companyId);
      await companyRepository.update(company!.copyWith(notes: 'first-update'));

      queueItems = _companyQueueItems(queueRepository, companyId);
      final firstUpdate = queueItems.last;

      expect(firstUpdate.operation, SyncOperation.update);
      expect(firstUpdate.status, SyncStatus.pending);

      await queueRepository.markProcessing(firstUpdate.id!);

      final afterFirstUpdate = await companyRepository.findById(companyId);
      await companyRepository.update(
        afterFirstUpdate!.copyWith(notes: 'second-update'),
      );

      queueItems = _companyQueueItems(queueRepository, companyId);

      final updateItems = queueItems
          .where((item) => item.operation == SyncOperation.update)
          .toList(growable: false);

      expect(updateItems.length, equals(2));
      expect(updateItems[0].status, SyncStatus.processing);
      expect(updateItems[1].status, SyncStatus.pending);
    },
  );
}
