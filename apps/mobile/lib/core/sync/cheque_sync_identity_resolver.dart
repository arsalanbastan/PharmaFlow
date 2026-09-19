import '../../data/models/cheque.dart';
import '../../data/repositories/local/local_cheque_repository.dart';
import '../../data/repositories/remote/remote_cheque_repository.dart';
import 'sync_identity_resolver.dart';

class ChequeSyncIdentityResolver {
  ChequeSyncIdentityResolver({
    required this._localChequeRepository,
    required RemoteChequeRepository remoteChequeRepository,
    required this._identityResolver,
  }) : _remoteChequeRepository = remoteChequeRepository;

  final LocalChequeRepository _localChequeRepository;
  final RemoteChequeRepository _remoteChequeRepository;
  final SyncIdentityResolver _identityResolver;

  Future<String> resolveServerUuid(Cheque cheque) async {
    final existing = cheque.serverUuid?.trim();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final companyUuid = await _identityResolver.resolveCompanyUuid(
      cheque.companyId,
    );
    final bankAccountUuid = await _identityResolver.resolveBankAccountUuid(
      cheque.bankAccountId,
    );

    final remoteCheques = await _remoteChequeRepository.getAll();
    final issueDate = _dateOnly(cheque.issueDate);
    final dueDate = _dateOnly(cheque.dueDate);
    final normalizedChequeNumber = cheque.chequeNumber.trim();
    final normalizedSayadId = cheque.sayadId?.trim();

    final candidates = remoteCheques
        .where((remoteCheque) {
          final remoteIssueDate = _dateOnly(remoteCheque.chequeDate);
          final remoteDueDate = remoteCheque.dueDate == null
              ? null
              : _dateOnly(remoteCheque.dueDate!);

          final sameSayadId =
              normalizedSayadId == null ||
              normalizedSayadId.isEmpty ||
              remoteCheque.sayadId == normalizedSayadId;

          return remoteCheque.companyId == companyUuid &&
              remoteCheque.bankAccountId == bankAccountUuid &&
              remoteCheque.chequeNumber == normalizedChequeNumber &&
              remoteCheque.amount.toInt() == cheque.amountRial &&
              remoteIssueDate == issueDate &&
              remoteDueDate == dueDate &&
              sameSayadId;
        })
        .toList(growable: false);

    if (candidates.isEmpty) {
      throw SyncIdentityMappingException(
        'Cheque local id ${cheque.id} has no unique remote UUID match.',
      );
    }

    if (candidates.length > 1) {
      throw SyncIdentityMappingException(
        'Cheque local id ${cheque.id} resolved to multiple remote UUID candidates.',
      );
    }

    final serverUuid = candidates.first.id;
    await _localChequeRepository.updateServerUuid(
      id: cheque.id,
      serverUuid: serverUuid,
    );
    return serverUuid;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
