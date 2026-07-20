import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../mappers/company_mapper.dart';
import '../../models/company.dart';
import '../exceptions/repository_exceptions.dart';
import '../interfaces/company_repository.dart';

class SqliteCompanyRepository implements CompanyRepository {
  SqliteCompanyRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  @override
  Future<Company> insert(Company company) async {
    final normalizedName = company.name.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    if (normalizedName.isEmpty) {
      throw ArgumentError('Company name cannot be empty.');
    }

    if (await existsByName(normalizedName)) {
      throw const DuplicateCompanyNameException();
    }

    _validateNationalId(company.nationalId);
    _validateEconomicCode(company.economicCode);

    final entity = company.copyWith(
      name: normalizedName,
    );

    final values = CompanyMapper.toMap(entity);

    values.remove('id');

    _databaseService.transaction((db) {
      final statement = db.prepare('''
        INSERT INTO companies (
          name,
          national_id,
          economic_code,
          notes,
          archived_at,
          created_at,
          updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''');

      statement.execute([
        values['name'],
        values['national_id'],
        values['economic_code'],
        values['notes'],
        values['archived_at'],
        values['created_at'],
        values['updated_at'],
      ]);

      statement.dispose();
    });

    final id =
        _db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

    return entity.copyWith(id: id);
  }

  @override
  Future<bool> existsByName(String name) async {
    final result = _db.select(
      '''
      SELECT COUNT(*) AS count
      FROM companies
      WHERE LOWER(name) = LOWER(?)
      ''',
      [name.trim()],
    );

    return (result.first['count'] as int) > 0;
  }

  void _validateNationalId(String? value) {
    if (value == null || value.isEmpty) return;

    if (!RegExp(r'^\d{11}$').hasMatch(value)) {
      throw const InvalidNationalIdException();
    }
  }

  void _validateEconomicCode(String? value) {
    if (value == null || value.isEmpty) return;

    if (!RegExp(r'^\d{10,16}$').hasMatch(value)) {
      throw const InvalidEconomicCodeException();
    }
  }

  // بقیه متدها را مرحله‌به‌مرحله پیاده می‌کنیم.
  @override
  Future<void> archive(int id) => throw UnimplementedError();

  @override
  Future<int> count({bool includeArchived = false}) =>
      throw UnimplementedError();

  @override
  Future<Company?> findById(int id) => throw UnimplementedError();

  @override
  Future<Company?> findByName(String name) =>
      throw UnimplementedError();

  @override
  Future<List<Company>> getAll({
    bool includeArchived = false,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> restore(int id) => throw UnimplementedError();

  @override
  Future<List<Company>> search(String query) =>
      throw UnimplementedError();

  @override
  Future<Company> update(Company company) =>
      throw UnimplementedError();
}