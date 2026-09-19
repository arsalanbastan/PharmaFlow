import '../../models/cash_payment_attachment.dart';

abstract class CashPaymentAttachmentRepository {
  Future<int> insert(CashPaymentAttachment attachment);

  Future<CashPaymentAttachment?> findById(int id);

  Future<CashPaymentAttachment?> findByServerUuid(String serverUuid);

  Future<List<CashPaymentAttachment>> findByCashPaymentId(
    int cashPaymentId, {
    bool includeDeleteRequested = false,
    bool includeDeleted = false,
  });

  Future<List<CashPaymentAttachment>> getAll({
    bool includeDeleteRequested = false,
    bool includeDeleted = false,
  });

  Future<void> requestDelete(int id);
}
