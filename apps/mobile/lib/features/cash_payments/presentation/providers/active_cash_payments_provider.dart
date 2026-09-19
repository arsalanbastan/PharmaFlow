import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/sync/sync_trigger.dart';
import '../../../../core/sync/sync_trigger_dispatcher.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/models/cash_payment.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cash_payment_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';

final localCashPaymentRepositoryProvider = Provider<LocalCashPaymentRepository>(
  (ref) {
    return LocalCashPaymentRepository(DatabaseService.instance);
  },
);

final cashPaymentMutationTriggerProvider = StreamProvider<SyncTrigger>((ref) {
  return SyncTriggerDispatcher.instance.stream;
});

final activeCashPaymentsProvider = FutureProvider<List<CashPayment>>((
  ref,
) async {
  ref.watch(cashPaymentMutationTriggerProvider);

  final repository = ref.watch(localCashPaymentRepositoryProvider);

  return repository.getAll();
});

class ActiveCashPaymentLookupData {
  const ActiveCashPaymentLookupData({
    required this.payments,
    required this.companyNames,
    required this.bankAccountNames,
  });

  final List<CashPayment> payments;
  final Map<int, String> companyNames;
  final Map<int, String> bankAccountNames;
}

final activeCashPaymentLookupProvider =
    FutureProvider<ActiveCashPaymentLookupData>((ref) async {
      final companyRepository = LocalCompanyRepository(
        DatabaseService.instance,
      );

      final bankAccountRepository = LocalBankAccountRepository(
        DatabaseService.instance,
      );

      final results = await Future.wait([
        ref.watch(activeCashPaymentsProvider.future),
        companyRepository.getAll(),
        bankAccountRepository.getAll(),
      ]);

      final payments = results[0] as List<CashPayment>;

      final companies = results[1] as List<Company>;

      final bankAccounts = results[2] as List<BankAccount>;

      final companyNames = <int, String>{
        for (final company in companies)
          if (company.id != null) company.id!: company.name,
      };

      final bankAccountNames = <int, String>{
        for (final account in bankAccounts)
          if (account.id != null)
            account.id!: '${account.bankName} - ${account.accountTitle}',
      };

      return ActiveCashPaymentLookupData(
        payments: payments,
        companyNames: companyNames,
        bankAccountNames: bankAccountNames,
      );
    });

void invalidateCashPaymentDependentProviders(ProviderContainer container) {
  container.invalidate(activeCashPaymentsProvider);
  container.invalidate(activeCashPaymentLookupProvider);
}
