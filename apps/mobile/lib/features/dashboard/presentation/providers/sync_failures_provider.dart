import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/sync/sync_operation.dart';
import '../../../../core/sync/sync_queue_item.dart';
import '../../../../core/sync/sync_status.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/models/company.dart';
import '../../../../data/models/cash_payment.dart';
import '../../../../data/models/cash_payment_attachment.dart';
import '../../../../data/models/cheque_attachment.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_cheque_attachment_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../../../data/repositories/local/local_cash_payment_repository.dart';
import '../../../../data/repositories/local/local_cash_payment_attachment_repository.dart';
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
    required this.resolutionHint,
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
  final String resolutionHint;
}

class SyncFailureActions {
  const SyncFailureActions(this._ref);

  final Ref _ref;

  Future<void> retry(int queueId) async {
    final syncEngine = _ref.read(syncServiceProvider);
    final queueRepository = _ref.read(syncQueueRepositoryProvider);
    await queueRepository.retryQueueItem(queueId);
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
      final queueRepository = _refQueue(ref);
      final chequeRepository = _refCheque(ref);
      final companyRepository = _refCompany(ref);
      final bankRepository = _refBank(ref);
      final cashPaymentRepository = _refCashPayment(ref);
      final attachmentRepository = _refCashPaymentAttachment(ref);
      final chequeAttachmentRepository = _refChequeAttachment(ref);

      final allItems = await queueRepository.getAllItems();
      final failedItems = allItems.where(
        (item) => switch (filter) {
          SyncFailuresFilter.failed => item.status == SyncStatus.failed,
          SyncFailuresFilter.pending =>
            item.status == SyncStatus.pending ||
                item.status == SyncStatus.processing,
          SyncFailuresFilter.completed => item.status == SyncStatus.synced,
        },
      );
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
          cashPaymentRepository: cashPaymentRepository,
          attachmentRepository: attachmentRepository,
          chequeAttachmentRepository: chequeAttachmentRepository,
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
            resolutionHint: details.resolutionHint,
          ),
        );
      }

      return entries;
    });

class _EntityDetails {
  const _EntityDetails({
    required this.title,
    required this.serverUuid,
    required this.resolutionHint,
  });

  final String title;
  final String? serverUuid;
  final String resolutionHint;
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

LocalCashPaymentRepository _refCashPayment(Ref ref) =>
    LocalCashPaymentRepository(DatabaseService.instance);

LocalCashPaymentAttachmentRepository _refCashPaymentAttachment(Ref ref) =>
    LocalCashPaymentAttachmentRepository(DatabaseService.instance);

LocalChequeAttachmentRepository _refChequeAttachment(Ref ref) =>
    LocalChequeAttachmentRepository(DatabaseService.instance);

Future<_EntityDetails> _resolveEntityDetails({
  required SyncQueueItem item,
  required LocalChequeRepository chequeRepository,
  required LocalCompanyRepository companyRepository,
  required LocalBankAccountRepository bankRepository,
  required LocalCashPaymentRepository cashPaymentRepository,
  required LocalCashPaymentAttachmentRepository attachmentRepository,
  required LocalChequeAttachmentRepository chequeAttachmentRepository,
}) async {
  final entityType = item.entityType.trim().toUpperCase();

  switch (entityType) {
    case syncEntityTypeCheque:
      final Cheque? cheque = await chequeRepository.findById(item.entityId);
      if (cheque == null) {
        return _EntityDetails(
          title: 'Cheque #${item.entityId} (not found)',
          serverUuid: null,
          resolutionHint: 'رکورد محلی چک پیدا نشد؛ جزئیات فنی را بررسی کنید.',
        );
      }

      final Company? company = await companyRepository.findById(
        cheque.companyId,
      );
      final companyName = company?.name ?? '—';
      return _EntityDetails(
        title: 'Cheque ${cheque.chequeNumber} - $companyName',
        serverUuid: cheque.serverUuid,
        resolutionHint: 'پس از بررسی مشخصات چک، تلاش مجدد همین رکورد را بزنید.',
      );
    case syncEntityTypeCompany:
      final Company? company = await companyRepository.findById(item.entityId);
      return _EntityDetails(
        title: company?.name ?? 'Company #${item.entityId} (not found)',
        serverUuid: company?.serverUuid,
        resolutionHint: 'پس از بررسی شرکت، تلاش مجدد همین رکورد را بزنید.',
      );
    case syncEntityTypeBankAccount:
      final BankAccount? account = await bankRepository.findById(item.entityId);
      if (account == null) {
        return _EntityDetails(
          title: 'Bank Account #${item.entityId} (not found)',
          serverUuid: null,
          resolutionHint: 'حساب بانکی محلی پیدا نشد؛ جزئیات فنی را بررسی کنید.',
        );
      }
      return _EntityDetails(
        title: '${account.bankName} - ${account.accountTitle}',
        serverUuid: account.serverUuid,
        resolutionHint: 'پس از بررسی حساب، تلاش مجدد همین رکورد را بزنید.',
      );
    case syncEntityTypeCashPayment:
      final CashPayment? payment = await cashPaymentRepository.findById(
        item.entityId,
      );
      if (payment == null) {
        return _EntityDetails(
          title: 'واریز نقدی #${item.entityId} (رکورد محلی یافت نشد)',
          serverUuid: null,
          resolutionHint:
              'رکورد واریز محلی پیدا نشد؛ جزئیات فنی را بررسی کنید.',
        );
      }
      final company = await companyRepository.findById(payment.companyId);
      return _EntityDetails(
        title:
            'واریز ${_formatRial(payment.amountRial)} ریال — ${company?.name ?? 'شرکت نامشخص'}'
            '${payment.trackingNumber == null ? '' : ' — پیگیری ${payment.trackingNumber}'}',
        serverUuid: payment.serverUuid,
        resolutionHint: 'پس از بررسی واریز، تلاش مجدد همین رکورد را بزنید.',
      );
    case syncEntityTypeChequeAttachment:
      final ChequeAttachment? attachment = await chequeAttachmentRepository
          .findById(item.entityId);
      if (attachment == null) {
        return _EntityDetails(
          title: 'ضمیمه چک #${item.entityId} (رکورد محلی یافت نشد)',
          serverUuid: null,
          resolutionHint:
              'رکورد ضمیمه محلی وجود ندارد؛ جزئیات فنی این رکورد را ارسال کنید.',
        );
      }
      final cheque = await chequeRepository.findById(attachment.chequeId);
      final company = cheque == null
          ? null
          : await companyRepository.findById(cheque.companyId);
      return _EntityDetails(
        title:
            '${attachment.fileName} — چک ${cheque?.chequeNumber ?? attachment.chequeId}'
            ' — ${company?.name ?? 'شرکت نامشخص'}'
            '${cheque == null ? '' : ' — ${_formatRial(cheque.amountRial)} ریال'}',
        serverUuid: attachment.serverUuid,
        resolutionHint: item.operation == SyncOperation.delete
            ? 'این عملیات فقط ضمیمه همین چک را حذف می‌کند، نه خود چک را. «تلاش مجدد همین رکورد» را بزنید.'
            : 'فایل ضمیمه و چک والد را بررسی و سپس تلاش مجدد را بزنید.',
      );
    case syncEntityTypeCashPaymentAttachment:
      final CashPaymentAttachment? attachment = await attachmentRepository
          .findById(item.entityId);
      if (attachment == null) {
        return _EntityDetails(
          title: 'ضمیمه واریز #${item.entityId} (فایل محلی یافت نشد)',
          serverUuid: null,
          resolutionHint: 'فایل محلی پیدا نشد؛ جزئیات فنی را بررسی کنید.',
        );
      }
      final payment = await cashPaymentRepository.findById(
        attachment.cashPaymentId,
      );
      final company = payment == null
          ? null
          : await companyRepository.findById(payment.companyId);
      return _EntityDetails(
        title:
            '${attachment.fileName} — ${company?.name ?? 'شرکت نامشخص'}'
            '${payment == null ? '' : ' — ${_formatRial(payment.amountRial)} ریال'}',
        serverUuid: attachment.serverUuid,
        resolutionHint: 'پس از بررسی فایل، تلاش مجدد همین رکورد را بزنید.',
      );
    default:
      return _EntityDetails(
        title: '$entityType #${item.entityId}',
        serverUuid: null,
        resolutionHint: 'جزئیات فنی رکورد را بررسی و ارسال کنید.',
      );
  }
}

String _formatRial(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
