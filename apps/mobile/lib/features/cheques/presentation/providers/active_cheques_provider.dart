import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/sync/sync_trigger.dart';
import '../../../../core/sync/sync_trigger_dispatcher.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/models/cheque.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import '../../../../data/repositories/local/local_cheque_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';

final localChequeRepositoryProvider = Provider<LocalChequeRepository>((ref) {
  return LocalChequeRepository(DatabaseService.instance);
});

final chequeMutationTriggerProvider = StreamProvider<SyncTrigger>((ref) {
  return SyncTriggerDispatcher.instance.stream;
});

final activeChequesProvider = FutureProvider<List<Cheque>>((ref) async {
  ref.watch(chequeMutationTriggerProvider);
  final repository = ref.watch(localChequeRepositoryProvider);
  return repository.getActiveCheques();
});

class ActiveChequeLookupData {
  const ActiveChequeLookupData({
    required this.cheques,
    required this.companyNames,
    required this.bankAccountNames,
    required this.bankAccountsById,
  });

  final List<Cheque> cheques;
  final Map<int, String> companyNames;
  final Map<int, String> bankAccountNames;
  final Map<int, BankAccount> bankAccountsById;
}

final activeChequeLookupProvider = FutureProvider<ActiveChequeLookupData>((
  ref,
) async {
  final companyRepository = LocalCompanyRepository(DatabaseService.instance);
  final bankAccountRepository = LocalBankAccountRepository(
    DatabaseService.instance,
  );

  final results = await Future.wait([
    ref.watch(activeChequesProvider.future),
    companyRepository.getAll(),
    bankAccountRepository.getAll(),
  ]);

  final cheques = results[0] as List<Cheque>;
  final companies = results[1] as List<Company>;
  final bankAccounts = results[2] as List<BankAccount>;

  final companyNames = <int, String>{
    for (final company in companies)
      if (company.id != null) company.id!: company.name,
  };

  final bankAccountNames = <int, String>{
    for (final account in bankAccounts)
      if (account.id != null) account.id!: account.accountTitle,
  };

  final bankAccountsById = <int, BankAccount>{
    for (final account in bankAccounts)
      if (account.id != null) account.id!: account,
  };

  return ActiveChequeLookupData(
    cheques: cheques,
    companyNames: companyNames,
    bankAccountNames: bankAccountNames,
    bankAccountsById: bankAccountsById,
  );
});

void invalidateChequeDependentProviders(ProviderContainer container) {
  container.invalidate(activeChequesProvider);
  container.invalidate(activeChequeLookupProvider);
}
