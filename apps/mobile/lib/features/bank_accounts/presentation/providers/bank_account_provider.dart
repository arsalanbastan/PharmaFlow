import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/bank_account.dart';
import '../../../../data/repositories/interfaces/bank_account_repository.dart';
import '../../../../data/repositories/local/local_bank_account_repository.dart';
import 'bank_account_state.dart';

final bankAccountRepositoryProvider =
    Provider<BankAccountRepository>((ref) {
  return LocalBankAccountRepository(DatabaseService.instance);
});

final bankAccountProvider =
    StateNotifierProvider<BankAccountNotifier, BankAccountState>(
  (ref) => BankAccountNotifier(
    ref.read(bankAccountRepositoryProvider),
  ),
);

class BankAccountNotifier extends StateNotifier<BankAccountState> {
  BankAccountNotifier(this._repository)
      : super(const BankAccountState());

  final BankAccountRepository _repository;

  Future<void> loadAccounts({
    bool includeArchived = false,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final accounts = await _repository.getAll(
        includeArchived: includeArchived,
      );

      state = state.copyWith(
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> search(
    String query, {
    bool includeArchived = false,
  }) async {
    state = state.copyWith(
      searchQuery: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final accounts = query.trim().isEmpty
          ? await _repository.getAll(includeArchived: includeArchived)
          : await _repository.search(
              query,
              includeArchived: includeArchived,
            );

      state = state.copyWith(
        accounts: accounts,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> addAccount(
    BankAccount account,
  ) async {
    await _repository.insert(account);
    await loadAccounts();
  }

  Future<void> updateAccount(
    BankAccount account,
  ) async {
    await _repository.update(account);
    await loadAccounts();
  }

  Future<void> archiveAccount(
    int id,
  ) async {
    await _repository.archive(id);
    await loadAccounts();
  }

  Future<void> restoreAccount(
    int id,
  ) async {
    await _repository.restore(id);
    await loadAccounts();
  }

  void clearError() {
    state = state.copyWith(
      clearError: true,
    );
  }
}