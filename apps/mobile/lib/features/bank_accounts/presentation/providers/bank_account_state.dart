import '../../../../data/models/bank_account.dart';

class BankAccountState {
  const BankAccountState({
    this.accounts = const [],
    this.isLoading = false,
    this.errorMessage,
    this.searchQuery = '',
  });

  final List<BankAccount> accounts;

  final bool isLoading;

  final String? errorMessage;

  final String searchQuery;

  BankAccountState copyWith({
    List<BankAccount>? accounts,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    String? searchQuery,
  }) {
    return BankAccountState(
      accounts: accounts ?? this.accounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage:
          clearError ? null : (errorMessage ?? this.errorMessage),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}