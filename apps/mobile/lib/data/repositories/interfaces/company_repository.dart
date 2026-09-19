import '../../models/company.dart';

abstract class CompanyRepository {
  Future<List<Company>> getAll({bool includeArchived = false});

  Future<List<Company>> search(String query, {bool includeArchived = false});

  Future<List<Company>> findSimilar(String name);

  Future<int> insert(Company company);

  Future<void> update(Company company);

  Future<void> archive(int id);

  Future<void> restore(int id);
}