import 'dart:async';

import '../../models/company.dart';
import '../interfaces/company_repository.dart';
import '../local/local_company_repository.dart';
import '../remote/remote_company_repository.dart';

class OfflineFirstCompanyRepository implements CompanyRepository {
  OfflineFirstCompanyRepository({
    required this._localRepository,
    required this._remoteRepository,
  });

  final LocalCompanyRepository _localRepository;
  final RemoteCompanyRepository _remoteRepository;

  @override
  Future<List<Company>> getAll({bool includeArchived = false}) async {
    final localCompanies = await _localRepository.getAll(
      includeArchived: includeArchived,
    );

    unawaited(_refreshFromRemote());

    return localCompanies;
  }

  @override
  Future<List<Company>> search(
    String query, {
    bool includeArchived = false,
  }) async {
    final localCompanies = await _localRepository.search(
      query,
      includeArchived: includeArchived,
    );

    unawaited(_refreshFromRemote());

    return localCompanies;
  }

  @override
  Future<List<Company>> findSimilar(String name) async {
    final localMatches = await _localRepository.findSimilar(name);

    unawaited(_refreshFromRemote());

    return localMatches;
  }

  @override
  Future<int> insert(Company company) {
    return _localRepository.insert(company);
  }

  @override
  Future<void> update(Company company) {
    return _localRepository.update(company);
  }

  @override
  Future<void> archive(int id) {
    return _localRepository.archive(id);
  }

  @override
  Future<void> restore(int id) {
    return _localRepository.restore(id);
  }

  Future<void> _refreshFromRemote() async {
    try {
      // TODO(sync): Remote synchronization is intentionally deferred.
      // A future CompanySyncService / SyncEngine will compare timestamps,
      // resolve conflicts, merge data, and then update local SQLite.
      // This repository must stay orchestration-only for offline-first reads.
      await _remoteRepository.getAll(includeArchived: true);
    } catch (_) {
      // Keep offline flow stable if remote is unavailable.
    }
  }
}
