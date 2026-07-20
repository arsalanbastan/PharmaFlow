import '../../models/company.dart';

abstract class CompanyRepository {
  Future<List<Company>> getAll();

  Future<List<Company>> search(String query);

  /// شرکت‌های مشابه را برمی‌گرداند
  Future<List<Company>> findSimilar(String name);

  Future<int> insert(Company company);

  Future<void> update(Company company);

  Future<void> archive(int id);
}