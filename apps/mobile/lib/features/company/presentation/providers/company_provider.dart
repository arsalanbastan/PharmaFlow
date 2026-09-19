import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/interfaces/company_repository.dart';
import '../../../../data/repositories/local/local_company_repository.dart';
import '../../../../data/repositories/offline_first/offline_first_company_repository.dart';
import '../../../../data/repositories/remote/remote_company_repository.dart';
import 'company_state.dart';

final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  final localRepository = LocalCompanyRepository(DatabaseService.instance);
  final remoteRepository = RemoteCompanyRepository(ApiClient());

  return OfflineFirstCompanyRepository(
    localRepository: localRepository,
    remoteRepository: remoteRepository,
  );
});

final companyProvider = StateNotifierProvider<CompanyNotifier, CompanyState>(
  (ref) => CompanyNotifier(ref.read(companyRepositoryProvider)),
);

final similarCompaniesProvider = StateProvider<List<Company>>((ref) => []);

class CompanyNotifier extends StateNotifier<CompanyState> {
  CompanyNotifier(this._repository) : super(const CompanyState());

  final CompanyRepository _repository;

  Future<void> loadCompanies({bool includeArchived = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final companies = await _repository.getAll(
        includeArchived: includeArchived,
      );

      state = state.copyWith(companies: companies, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> search(String query, {bool includeArchived = false}) async {
    state = state.copyWith(
      searchQuery: query,
      isLoading: true,
      clearError: true,
    );

    try {
      final companies = query.trim().isEmpty
          ? await _repository.getAll(includeArchived: includeArchived)
          : await _repository.search(query, includeArchived: includeArchived);

      state = state.copyWith(companies: companies, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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

  Future<void> restoreCompany(int id) async {
    await _repository.restore(id);
    await loadCompanies();
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
