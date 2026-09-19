import '../../models/cheque_attachment.dart';

abstract class ChequeAttachmentRepository {
  Future<int> insert(ChequeAttachment attachment);

  Future<ChequeAttachment?> findById(int id);

  Future<ChequeAttachment?> findByServerUuid(String serverUuid);

  Future<List<ChequeAttachment>> findByChequeId(
    int chequeId, {
    bool includeDeleteRequested = false,
    bool includeDeleted = false,
  });

  Future<List<ChequeAttachment>> getAll({
    bool includeDeleteRequested = false,
    bool includeDeleted = false,
  });

  Future<void> requestDelete(int id);
}
