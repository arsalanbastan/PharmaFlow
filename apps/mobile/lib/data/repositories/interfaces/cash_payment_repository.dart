import '../../models/cash_payment.dart';

abstract class CashPaymentRepository {
  Future<int> insert(CashPayment payment);

  Future<void> update(CashPayment payment);

  Future<CashPayment?> findById(int id);

  Future<CashPayment?> findByServerUuid(String serverUuid);

  Future<List<CashPayment>> getAll({
    bool includeArchived = false,
    bool includeDeleteRequested = false,
  });

  Future<List<CashPayment>> findByCompanyId(
    int companyId, {
    bool includeArchived = false,
    bool includeDeleteRequested = false,
  });

  Future<List<CashPayment>> findByBankAccountId(
    int bankAccountId, {
    bool includeArchived = false,
    bool includeDeleteRequested = false,
  });

  Future<void> archive(int id);

  Future<void> restore(int id);

  Future<void> requestDelete(int id);

  Future<void> updateServerUuid({
    required int localId,
    required String serverUuid,
  });
}
