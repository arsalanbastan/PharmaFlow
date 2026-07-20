import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/interfaces/company_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';

import 'company_state.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return LocalCompanyRepository(
    DatabaseService.instance,
  );
});

final companyProvider =
    StateNotifierProvider<CompanyNotifier, CompanyState>(
  (ref) {
    return CompanyNotifier(
      ref.read(companyRepositoryProvider),
    );
  },
);

final similarCompaniesProvider =
    StateProvider<List<Company>>((ref) => []);

class CompanyNotifier extends StateNotifier<CompanyState> {
  CompanyNotifier(this._repository)
      : super(const CompanyState());

  final CompanyRepository _repository;

  Future<void> loadCompanies() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final companies = await _repository.getAll();

      state = state.copyWith(
        companies: companies,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> search(String query) async {
    state = state.copyWith(
      searchQuery: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final companies = query.trim().isEmpty
          ? await _repository.getAll()
          : await _repository.search(query);

      state = state.copyWith(
        companies: companies,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<List<Company>> findSimilar(String name) async {
    if (name.trim().isEmpty) {
      return [];
    }

    return _repository.findSimilar(name);
  }

  Future<void> addCompany(Company company) async {
    await _repository.insert(company);
    await loadCompanies();
  }

  Future<void> updateCompany(Company company) async {
    await _repository.update(company);
    await loadCompanies();
  }

  Future<void> archiveCompany(int id) async {
    await _repository.archive(id);
    await loadCompanies();
  }

  void clearError() {
    state = state.copyWith(
      clearError: true,
    );
  }
}