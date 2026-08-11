import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/sync/sync_operation.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../../../data/repositories/local/sync_queue_repository.dart';
import '../../../settings/presentation/providers/communication_settings_provider.dart';

enum SyncFailuresFilter { pending, failed, completed }

class SyncFailureEntry {
  const SyncFailureEntry({
    required this.queueId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.status,
    required this.retryCount,
    required this.lastError,
    required this.createdAt,
    required this.updatedAt,
    required this.entityTitle,
    required this.serverUuid,
  });

  final int queueId;
  final String entityType;
  final int entityId;
  final String operation;
  final String status;
  final int retryCount;
  final String? lastError;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String entityTitle;
  final String? serverUuid;
}

class SyncFailureActions {
  const SyncFailureActions(this._ref);

  final Ref _ref;

  Future<void> retry(int queueId) async {
    final syncEngine = _ref.read(syncServiceProvider);

    await syncEngine.retryManually();
    await syncEngine.refreshState();
  }

  Future<void> deleteError(int queueId) async {
    final queueRepository = _ref.read(syncQueueRepositoryProvider);
    final item = await queueRepository.findById(queueId);

    // Guard: never discard an active unsynced financial operation.
    if (item != null &&
        (item.status == SyncStatus.failed ||
            item.status == SyncStatus.pending ||
            item.status == SyncStatus.processing)) {
      throw StateError(
        'Queue item #$queueId (${item.status.dbValue}) represents an unsynced'
        ' financial change and cannot be discarded. Use Retry instead.',
      );
    }

    final syncEngine = _ref.read(syncServiceProvider);
    await queueRepository.deleteQueueItem(queueId);
    await syncEngine.refreshState();
  }
}

final syncFailureActionsProvider = Provider<SyncFailureActions>((ref) {
  return SyncFailureActions(ref);
});

final syncFailuresProvider =
    FutureProvider.family<List<SyncFailureEntry>, SyncFailuresFilter>((
      ref,
      filter,
    ) async {
      if (filter != SyncFailuresFilter.failed) {
        return const <SyncFailureEntry>[];
      }

      final queueRepository = _refQueue(ref);
      final chequeRepository = _refCheque(ref);
      final companyRepository = _refCompany(ref);
      final bankRepository = _refBank(ref);

      final failedItems = await queueRepository.getFailedItems();
      final entries = <SyncFailureEntry>[];

      for (final item in failedItems) {
        final queueId = item.id;
        if (queueId == null) {
          continue;
        }

        final details = await _resolveEntityDetails(
          item: item,
          chequeRepository: chequeRepository,
          companyRepository: companyRepository,
          bankRepository: bankRepository,
        );

        entries.add(
          SyncFailureEntry(
            queueId: queueId,
            entityType: item.entityType,
            entityId: item.entityId,
            operation: item.operation.dbValue,
            status: item.status.dbValue,
            retryCount: item.retryCount,
            lastError: item.errorMessage,
            createdAt: item.createdAt,
            updatedAt: item.lastAttemptAt,
            entityTitle: details.title,
            serverUuid: details.serverUuid,
          ),
        );
      }

      return entries;
    });

class _EntityDetails {
  const _EntityDetails({required this.title, required this.serverUuid});

  final String title;
  final String? serverUuid;
}

SyncQueueRepository _refQueue(Ref ref) {
  return ref.read(syncQueueRepositoryProvider);
}

LocalChequeRepository _refCheque(Ref ref) {
  return LocalChequeRepository(DatabaseService.instance);
}

LocalCompanyRepository _refCompany(Ref ref) {
  return LocalCompanyRepository(DatabaseService.instance);
}

LocalBankAccountRepository _refBank(Ref ref) {
  return LocalBankAccountRepository(DatabaseService.instance);
}

Future<_EntityDetails> _resolveEntityDetails({
  required SyncQueueItem item,
  required LocalChequeRepository chequeRepository,
  required LocalCompanyRepository companyRepository,
  required LocalBankAccountRepository bankRepository,
}) async {
  final entityType = item.entityType.trim().toUpperCase();

  switch (entityType) {
    case syncEntityTypeCheque:
      final Cheque? cheque = await chequeRepository.findById(item.entityId);
      if (cheque == null) {
        return _EntityDetails(
          title: 'Cheque #${item.entityId} (not found)',
          serverUuid: null,
        );
      }

      final Company? company = await companyRepository.findById(
        cheque.companyId,
      );
      final companyName = company?.name ?? '—';
      return _EntityDetails(
        title: 'Cheque ${cheque.chequeNumber} - $companyName',
        serverUuid: cheque.serverUuid,
      );
    case syncEntityTypeCompany:
      final Company? company = await companyRepository.findById(item.entityId);
      return _EntityDetails(
        title: company?.name ?? 'Company #${item.entityId} (not found)',
        serverUuid: company?.serverUuid,
      );
    case syncEntityTypeBankAccount:
      final BankAccount? account = await bankRepository.findById(item.entityId);
      if (account == null) {
        return _EntityDetails(
          title: 'Bank Account #${item.entityId} (not found)',
          serverUuid: null,
        );
      }
      return _EntityDetails(
        title: '${account.bankName} - ${account.accountTitle}',
        serverUuid: account.serverUuid,
      );
    default:
      return _EntityDetails(
        title: '$entityType #${item.entityId}',
        serverUuid: null,
      );
  }
}
