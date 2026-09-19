import '../../models/cheque.dart';

abstract class ChequeRepository {
  Future<int> insert(Cheque cheque);

  Future<void> update(Cheque cheque);

  Future<void> requestDelete(int id);

  Future<Cheque?> findById(int id);

  Future<List<Cheque>> getActiveCheques();

  Future<List<Cheque>> getAll({
    bool includeArchived = false,
    bool includeCancelled = false,
  });

  Future<List<Cheque>> findByDateRange({
    DateTime? fromDate,
    DateTime? toDate,
    bool includeArchived = false,
    bool includeCancelled = false,
  });

  Future<List<Cheque>> findByCompanyId(
    int companyId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool includeArchived = false,
    bool includeCancelled = false,
  });

  Future<List<Cheque>> findByBankAccountId(
    int bankAccountId, {
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    bool includeArchived = false,
    bool includeCancelled = false,
  });

  Future<List<Cheque>> search(
    String query, {
    DateTime? fromDate,
    DateTime? toDate,
    int? companyId,
    int? bankAccountId,
    bool includeArchived = false,
    bool includeCancelled = false,
  });

  Future<List<Cheque>> findDuplicatesByBankAccountAndChequeNumber({
    required int bankAccountId,
    required String chequeNumber,
  });

  Future<String?> suggestLatestChequeNumber(int bankAccountId);

  Future<int> count({
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
    int? companyId,
    int? bankAccountId,
    bool includeArchived = false,
    bool includeCancelled = false,
  });
}
