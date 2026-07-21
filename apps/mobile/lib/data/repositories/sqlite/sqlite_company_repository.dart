import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/utils/company_name_normalizer.dart';
import '../../mappers/company_mapper.dart';
import '../../models/company.dart';
import '../exceptions/repository_exceptions.dart';
import '../interfaces/company_repository.dart';

class SqliteCompanyRepository implements CompanyRepository {
  SqliteCompanyRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  @override
  Future<int> insert(Company company) async {
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
          visitor_name,
          visitor_phone,
          accountant_name,
          accountant_phone,
          archived_at,
          created_at,
          updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      statement.execute([
        values['name'],
        values['national_id'],
        values['economic_code'],
        values['notes'],
        values['visitor_name'],
        values['visitor_phone'],
        values['accountant_name'],
        values['accountant_phone'],
        values['archived_at'],
        values['created_at'],
        values['updated_at'],
      ]);

      statement.dispose();
    });

    final id =
        _db.select('SELECT last_insert_rowid() AS id').first['id'] as int;

    return id;
  }

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

  Future<Company?> findById(int id) async {
    final result = _db.select('SELECT * FROM companies WHERE id = ? LIMIT 1', [id]);

    if (result.isEmpty) {
      return null;
    }

    return CompanyMapper.fromMap(result.first);
  }

  Future<Company?> findByName(String name) async {
    final result = _db.select(
      '''
      SELECT *
      FROM companies
      WHERE archived_at IS NULL
        AND LOWER(name) = LOWER(?)
      LIMIT 1
      ''',
      [name.trim()],
    );

    if (result.isEmpty) {
      return null;
    }

    return CompanyMapper.fromMap(result.first);
  }

  @override
  Future<List<Company>> getAll({bool includeArchived = false}) async {
    final result = includeArchived
        ? _db.select('SELECT * FROM companies ORDER BY name COLLATE NOCASE')
        : _db.select(
            'SELECT * FROM companies WHERE archived_at IS NULL ORDER BY name COLLATE NOCASE',
          );

    return result.map((row) => CompanyMapper.fromMap(row)).toList();
  }

  @override
  Future<List<Company>> search(String query, {bool includeArchived = false}) async {
    final keyword = '%${query.trim()}%';
    final result = _db.select(
      includeArchived
          ? '''
      SELECT *
      FROM companies
      WHERE (
        LOWER(name) LIKE LOWER(?)
        OR national_id LIKE ?
        OR economic_code LIKE ?
      )
      ORDER BY name COLLATE NOCASE
      '''
          : '''
      SELECT *
      FROM companies
      WHERE archived_at IS NULL
        AND (
          LOWER(name) LIKE LOWER(?)
          OR national_id LIKE ?
          OR economic_code LIKE ?
        )
      ORDER BY name COLLATE NOCASE
      ''',
      [keyword, keyword, keyword],
    );

    return result.map((row) => CompanyMapper.fromMap(row)).toList();
  }

  @override
  Future<void> archive(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      'UPDATE companies SET archived_at = ?, updated_at = ? WHERE id = ?',
      [now, now, id],
    );
  }

  @override
  Future<void> restore(int id) async {
    _db.execute(
      'UPDATE companies SET archived_at = NULL, updated_at = ? WHERE id = ?',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<int> count({bool includeArchived = false}) async {
    final result = includeArchived
        ? _db.select('SELECT COUNT(*) AS count FROM companies')
        : _db.select(
            'SELECT COUNT(*) AS count FROM companies WHERE archived_at IS NULL',
          );

    return result.first['count'] as int;
  }

  @override
  Future<void> update(Company company) async {
    if (company.id == null) {
      throw const CompanyNotFoundException();
    }

    final normalizedName = company.name.trim().replaceAll(RegExp(r'\s+'), ' ');

    final duplicate = _db.select(
      '''
      SELECT id
      FROM companies
      WHERE archived_at IS NULL
        AND LOWER(name) = LOWER(?)
        AND id <> ?
      LIMIT 1
      ''',
      [normalizedName, company.id],
    );

    if (duplicate.isNotEmpty) {
      throw const DuplicateCompanyNameException();
    }

    final entity = company.copyWith(
      name: normalizedName,
      updatedAt: DateTime.now(),
    );

    final values = CompanyMapper.toMap(entity);

    _db.execute(
      '''
      UPDATE companies
      SET
        name = ?,
        national_id = ?,
        economic_code = ?,
        notes = ?,
        visitor_name = ?,
        visitor_phone = ?,
        accountant_name = ?,
        accountant_phone = ?,
        archived_at = ?,
        updated_at = ?
      WHERE id = ?
      ''',
      [
        values['name'],
        values['national_id'],
        values['economic_code'],
        values['notes'],
        values['visitor_name'],
        values['visitor_phone'],
        values['accountant_name'],
        values['accountant_phone'],
        values['archived_at'],
        values['updated_at'],
        company.id,
      ],
    );
  }

  @override
  Future<List<Company>> findSimilar(String name) async {
    final companies = await getAll();
    final normalizedInput = CompanyNameNormalizer.normalize(name);

    if (normalizedInput.isEmpty) {
      return [];
    }

    return companies.where((company) {
      final normalizedCompany = CompanyNameNormalizer.normalize(company.name);

      return normalizedCompany.contains(normalizedInput) ||
          normalizedInput.contains(normalizedCompany);
    }).toList();
  }
}