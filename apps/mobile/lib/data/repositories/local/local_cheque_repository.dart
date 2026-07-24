import 'package:sqlite3/sqlite3.dart';

import '../../../core/database/database_service.dart';
import '../../../core/database/queries/cheque_queries.dart';
import '../../mappers/cheque_mapper.dart';
import '../../models/cheque.dart';
import '../interfaces/cheque_repository.dart';

class LocalChequeRepository implements ChequeRepository {
  LocalChequeRepository(this._databaseService);

  final DatabaseService _databaseService;

  Database get _db => _databaseService.database;

  @override
  Future<int> insert(Cheque cheque) async {
    final values = ChequeMapper.toMap(cheque);
    values.remove('id');

    _databaseService.transaction((db) {
      final statement = db.prepare(ChequeQueries.insert);
      statement.execute(_namedParams(values));
      statement.dispose();
    });

    return _db.select('SELECT last_insert_rowid() AS id').first['id'] as int;
  }

  @override
  Future<void> update(Cheque cheque) async {
    final values = ChequeMapper.toMap(cheque);
    final statement = _db.prepare(ChequeQueries.updateEditableById);

    try {
      statement.execute(_namedParams(values));
    } finally {
      statement.dispose();
    }
  }

  @override
  Future<Cheque?> findById(int id) async {
    final result = _select(
      ChequeQueries.findById,
      {
        'id': id,
      },
    );

    if (result.isEmpty) {
      return null;
    }

    return ChequeMapper.fromMap(result.first);
  }

  @override
  Future<List<Cheque>> getAll({
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findList,
      _listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
      ),
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findByDateRange({
    DateTime? fromDate,
    DateTime? toDate,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findList,
      _listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
        fromDate: fromDate,
        toDate: toDate,
      ),
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findByCompanyId(
    int companyId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findByCompanyId,
      {
        ..._listParams(
          includeArchived: includeArchived,
          includeCancelled: includeCancelled,
          fromDate: fromDate,
          toDate: toDate,
          search: search,
        ),
        'companyId': companyId,
      },
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findByBankAccountId(
    int bankAccountId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findByBankAccountId,
      {
        ..._listParams(
          includeArchived: includeArchived,
          includeCancelled: includeCancelled,
          fromDate: fromDate,
          toDate: toDate,
          search: search,
        ),
        'bankAccountId': bankAccountId,
      },
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> search(
    String query, {
    DateTime? fromDate,
    DateTime? toDate,
    int? companyId,
    int? bankAccountId,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final result = _select(
      ChequeQueries.findList,
      _listParams(
        includeArchived: includeArchived,
        includeCancelled: includeCancelled,
        fromDate: fromDate,
        toDate: toDate,
        search: query,
        companyId: companyId,
        bankAccountId: bankAccountId,
      ),
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<List<Cheque>> findDuplicatesByBankAccountAndChequeNumber({
    required int bankAccountId,
    required String chequeNumber,
  }) async {
    final result = _select(
      ChequeQueries.findDuplicatesByBankAccountAndChequeNumber,
      {
        'bankAccountId': bankAccountId,
        'chequeNumber': chequeNumber,
      },
    );

    return result.map(ChequeMapper.fromMap).toList();
  }

  @override
  Future<String?> suggestLatestChequeNumber(int bankAccountId) async {
    final result = _select(
      ChequeQueries.findLatestChequeNumberByBankAccountId,
      {
        'bankAccountId': bankAccountId,
      },
    );

    if (result.isEmpty) {
      return null;
    }

    return result.first['cheque_number'] as String?;
  }

  @override
  Future<int> count({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int? companyId,
    int? bankAccountId,
    bool includeArchived = false,
    bool includeCancelled = false,
  }) async {
    final sql = companyId != null
        ? ChequeQueries.countByCompanyId
        : bankAccountId != null
            ? ChequeQueries.countByBankAccountId
            : ChequeQueries.countList;

    final params = _listParams(
      includeArchived: includeArchived,
      includeCancelled: includeCancelled,
      fromDate: fromDate,
      toDate: toDate,
      search: search,
      companyId: companyId,
      bankAccountId: bankAccountId,
    );

    final result = _select(sql, params);
    return result.first['total'] as int;
  }

  ResultSet _select(String sql, Map<String, Object?> params) {
    final statement = _db.prepare(sql);

    try {
      return statement.select(_namedParams(params));
    } finally {
      statement.dispose();
    }
  }

  Map<String, Object?> _namedParams(Map<String, Object?> params) {
    final named = <String, Object?>{};

    for (final entry in params.entries) {
      named[':${entry.key}'] = entry.value;
    }

    return named;
  }

  Map<String, Object?> _listParams({
    required bool includeArchived,
    required bool includeCancelled,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int? companyId,
    int? bankAccountId,
  }) {
    return {
      'includeArchived': includeArchived ? 1 : 0,
      'includeCancelled': includeCancelled ? 1 : 0,
      'fromDate': fromDate?.millisecondsSinceEpoch,
      'toDate': toDate?.millisecondsSinceEpoch,
      'search': search,
      'companyId': companyId,
      'bankAccountId': bankAccountId,
    };
  }
}