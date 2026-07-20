import '../../../../data/models/company.dart';

class CompanyState {
  const CompanyState({
    this.companies = const [],
    this.isLoading = false,
    this.searchQuery = '',
    this.errorMessage,
  });

  final List<Company> companies;
  final bool isLoading;
  final String searchQuery;
  final String? errorMessage;

  CompanyState copyWith({
    List<Company>? companies,
    bool? isLoading,
    String? searchQuery,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CompanyState(
      companies: companies ?? this.companies,
      isLoading: isLoading ?? this.isLoading,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: clearError
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}