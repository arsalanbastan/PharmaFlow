enum CashPaymentMethod { bankDeposit, posPayment }

class CashPayment {
  const CashPayment({
    this.id,
    this.serverUuid,
    required this.amountRial,
    required this.paymentDate,
    required this.companyId,
    required this.bankAccountId,
    required this.paymentMethod,
    this.trackingNumber,
    this.description,
    this.notes,
    this.archivedAt,
    this.deleteRequestedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String? serverUuid;

  final int amountRial;
  final DateTime paymentDate;

  final int companyId;
  final int bankAccountId;

  final CashPaymentMethod paymentMethod;

  final String? trackingNumber;
  final String? description;
  final String? notes;

  final DateTime? archivedAt;

  /// Local deletion intent.
  ///
  /// Sync wiring is intentionally deferred to the next phase.
  final DateTime? deleteRequestedAt;

  /// Server tombstone state after a future pull/merge.
  final DateTime? deletedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  CashPayment copyWith({
    Object? id = _unset,
    Object? serverUuid = _unset,
    int? amountRial,
    DateTime? paymentDate,
    int? companyId,
    int? bankAccountId,
    CashPaymentMethod? paymentMethod,
    Object? trackingNumber = _unset,
    Object? description = _unset,
    Object? notes = _unset,
    Object? archivedAt = _unset,
    Object? deleteRequestedAt = _unset,
    Object? deletedAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CashPayment(
      id: identical(id, _unset) ? this.id : id as int?,
      serverUuid: identical(serverUuid, _unset)
          ? this.serverUuid
          : serverUuid as String?,
      amountRial: amountRial ?? this.amountRial,
      paymentDate: paymentDate ?? this.paymentDate,
      companyId: companyId ?? this.companyId,
      bankAccountId: bankAccountId ?? this.bankAccountId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      trackingNumber: identical(trackingNumber, _unset)
          ? this.trackingNumber
          : trackingNumber as String?,
      description: identical(description, _unset)
          ? this.description
          : description as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      archivedAt: identical(archivedAt, _unset)
          ? this.archivedAt
          : archivedAt as DateTime?,
      deleteRequestedAt: identical(deleteRequestedAt, _unset)
          ? this.deleteRequestedAt
          : deleteRequestedAt as DateTime?,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

const Object _unset = Object();
