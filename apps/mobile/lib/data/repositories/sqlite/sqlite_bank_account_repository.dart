import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../mappers/bank_account_mapper.dart';
import '../../models/bank_account.dart';
import '../exceptions/repository_exceptions.dart';
import '../interfaces/bank_account_repository.dart';

class SqliteBankAccountRepository implements BankAccountRepository {
  SqliteBankAccountRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  String _normalizeAccountTitle(String value) {
    return value.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
  }

  List<BankAccount> _mapAccounts(ResultSet result) {
    return result.map(BankAccountMapper.fromMap).toList();
  }

  @override
  Future<int> insert(BankAccount account) async {
    final normalizedAccountTitle = _normalizeAccountTitle(
      account.accountTitle,
    );

    if (normalizedAccountTitle.isEmpty) {
      throw ArgumentError('Bank account title cannot be empty.');
    }

    if (await existsByName(normalizedAccountTitle)) {
      throw const DuplicateBankAccountNameException();
    }

    final values = BankAccountMapper.toMap(account);

    values.remove('id');
    values['account_title'] = normalizedAccountTitle;

    _databaseService.transaction((db) {
      final statement = db.prepare('''
        INSERT INTO bank_accounts (
          bank_name,
          account_title,
          account_holder,
          account_number,
          card_number,
          iban,
          note,
          archived_at,
          created_at,
          updated_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''');

      statement.execute([
        values['bank_name'],
        values['account_title'],
        values['account_holder'],
        values['account_number'],
        values['card_number'],
        values['iban'],
        values['note'],
        values['archived_at'],
        values['created_at'],
        values['updated_at'],
      ]);

      statement.dispose();
    });

    final id =
        _db.select(
          'SELECT last_insert_rowid() AS id',
        ).first['id'] as int;

    return id;
  }

  @override
  Future<List<BankAccount>> getAll({
    bool includeArchived = false,
  }) async {
    final result = includeArchived
        ? _db.select(
            '''
            SELECT *
            FROM bank_accounts
            ORDER BY bank_name COLLATE NOCASE,
                     account_title COLLATE NOCASE
            ''',
          )
        : _db.select(
            '''
            SELECT *
            FROM bank_accounts
            WHERE (archived_at IS NULL OR archived_at = 0)
            ORDER BY bank_name COLLATE NOCASE,
                     account_title COLLATE NOCASE
            ''',
          );

    return _mapAccounts(result);
  }

  @override
  Future<List<BankAccount>> search(
    String query, {
    bool includeArchived = false,
  }) async {
    final keyword = '%${query.trim()}%';
    final result = _db.select(
      includeArchived
          ? '''
            SELECT *
            FROM bank_accounts
            WHERE (
              LOWER(account_title) LIKE LOWER(?)
              OR LOWER(bank_name) LIKE LOWER(?)
              OR LOWER(account_holder) LIKE LOWER(?)
              OR account_number LIKE ?
              OR card_number LIKE ?
              OR LOWER(iban) LIKE LOWER(?)
            )
            ORDER BY bank_name COLLATE NOCASE,
                     account_title COLLATE NOCASE
            '''
          : '''
            SELECT *
            FROM bank_accounts
            WHERE (archived_at IS NULL OR archived_at = 0)
              AND (
                LOWER(account_title) LIKE LOWER(?)
                OR LOWER(bank_name) LIKE LOWER(?)
                OR LOWER(account_holder) LIKE LOWER(?)
                OR account_number LIKE ?
                OR card_number LIKE ?
                OR LOWER(iban) LIKE LOWER(?)
              )
            ORDER BY bank_name COLLATE NOCASE,
                     account_title COLLATE NOCASE
            ''',
      [keyword, keyword, keyword, keyword, keyword, keyword],
    );

    return _mapAccounts(result);
  }

  @override
  Future<BankAccount?> getById(int id) async {
    return findById(id);
  }

  @override
  Future<BankAccount?> findById(int id) async {
    final result = _db.select(
      '''
      SELECT *
      FROM bank_accounts
      WHERE id = ?
      LIMIT 1
      ''',
      [id],
    );

    if (result.isEmpty) {
      return null;
    }

    return BankAccountMapper.fromMap(result.first);
  }

  @override
  Future<bool> existsByName(String name) async {
    final normalizedName = _normalizeAccountTitle(name);

    if (normalizedName.isEmpty) {
      return false;
    }

    final result = _db.select(
      '''
      SELECT COUNT(*) AS count
      FROM bank_accounts
      WHERE (archived_at IS NULL OR archived_at = 0)
        AND LOWER(account_title) = LOWER(?)
      ''',
      [normalizedName],
    );

    return (result.first['count'] as int) > 0;
  }

  @override
  Future<int> count({
    bool includeArchived = false,
  }) async {
    final result = includeArchived
        ? _db.select('SELECT COUNT(*) AS count FROM bank_accounts')
        : _db.select(
            'SELECT COUNT(*) AS count FROM bank_accounts WHERE (archived_at IS NULL OR archived_at = 0)',
          );

    return result.first['count'] as int;
  }

  @override
  Future<void> update(BankAccount account) async {
    if (account.id == null) {
      throw ArgumentError('Bank account id cannot be null.');
    }

    final normalizedAccountTitle = _normalizeAccountTitle(
      account.accountTitle,
    );

    if (normalizedAccountTitle.isEmpty) {
      throw ArgumentError('Bank account title cannot be empty.');
    }

    final duplicate = _db.select(
      '''
      SELECT id
      FROM bank_accounts
      WHERE (archived_at IS NULL OR archived_at = 0)
        AND LOWER(account_title) = LOWER(?)
        AND id <> ?
      LIMIT 1
      ''',
      [normalizedAccountTitle, account.id],
    );

    if (duplicate.isNotEmpty) {
      throw const DuplicateBankAccountNameException();
    }

    final values = BankAccountMapper.toMap(account);
    values['account_title'] = normalizedAccountTitle;

    _db.execute(
      '''
      UPDATE bank_accounts
      SET
        bank_name = ?,
        account_title = ?,
        account_holder = ?,
        account_number = ?,
        card_number = ?,
        iban = ?,
        note = ?,
        archived_at = ?,
        updated_at = ?
      WHERE id = ?
      ''',
      [
        values['bank_name'],
        values['account_title'],
        values['account_holder'],
        values['account_number'],
        values['card_number'],
        values['iban'],
        values['note'],
        values['archived_at'],
        DateTime.now().millisecondsSinceEpoch,
        account.id,
      ],
    );
  }

  @override
  Future<void> archive(int id) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    _db.execute(
      '''
      UPDATE bank_accounts
      SET
        archived_at = ?,
        updated_at = ?
      WHERE id = ?
      ''',
      [
        now,
        now,
        id,
      ],
    );
  }

  @override
  Future<void> restore(int id) async {
    _db.execute(
      '''
      UPDATE bank_accounts
      SET
        archived_at = NULL,
        updated_at = ?
      WHERE id = ?
      ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        id,
      ],
    );
  }

  @override
  Future<void> delete(int id) async {
    _db.execute(
      '''
      DELETE FROM bank_accounts
      WHERE id = ?
      ''',
      [
        id,
      ],
    );
  }
}