class FcmOrderTarget {
  const FcmOrderTarget({required this.orderId});

  static const String orderCreatedType = 'ORDER_CREATED';

  final String orderId;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static FcmOrderTarget? fromData(Map<String, dynamic> data) {
    final type = _readString(data['type'])?.toUpperCase();

    if (type != orderCreatedType) {
      return null;
    }

    final orderId = _readString(data['orderId']);

    if (orderId == null || !_uuidPattern.hasMatch(orderId)) {
      return null;
    }

    return FcmOrderTarget(orderId: orderId);
  }

  static String? _readString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

enum FcmPushTargetKind { order, cheque, cashPayment }

class FcmPushTarget {
  const FcmPushTarget({
    required this.kind,
    required this.type,
    required this.id,
    this.notificationDeliveryId,
  });

  static const String orderCreatedType = 'ORDER_CREATED';
  static const String chequeCreatedType = 'CHEQUE_CREATED';
  static const String cashPaymentCreatedType = 'CASH_PAYMENT_CREATED';

  final FcmPushTargetKind kind;
  final String type;
  final String id;
  final String? notificationDeliveryId;

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static FcmPushTarget? fromData(Map<String, dynamic> data) {
    final type = _readString(data['type'])?.toUpperCase();

    final (kind, idKey) = switch (type) {
      orderCreatedType => (FcmPushTargetKind.order, 'orderId'),
      chequeCreatedType => (FcmPushTargetKind.cheque, 'chequeId'),
      cashPaymentCreatedType => (
        FcmPushTargetKind.cashPayment,
        'cashPaymentId',
      ),
      _ => (null, null),
    };

    if (kind == null || idKey == null || type == null) {
      return null;
    }

    final id = _readString(data[idKey]);

    if (id == null || !_uuidPattern.hasMatch(id)) {
      return null;
    }

    final rawDeliveryId = _readString(data['notificationDeliveryId']);

    final notificationDeliveryId =
        rawDeliveryId != null && _uuidPattern.hasMatch(rawDeliveryId)
        ? rawDeliveryId
        : null;

    return FcmPushTarget(
      kind: kind,
      type: type,
      id: id,
      notificationDeliveryId: notificationDeliveryId,
    );
  }

  static FcmPushTarget? fromNative(Object? value) {
    if (value is String) {
      return fromData(<String, dynamic>{
        'type': orderCreatedType,
        'orderId': value,
      });
    }

    if (value is! Map) {
      return null;
    }

    final type = _readString(value['type'])?.toUpperCase();
    final id = _readString(value['id']);
    final deliveryId = _readString(value['deliveryId']);

    if (type == null || id == null) {
      return null;
    }

    final idKey = switch (type) {
      orderCreatedType => 'orderId',
      chequeCreatedType => 'chequeId',
      cashPaymentCreatedType => 'cashPaymentId',
      _ => null,
    };

    if (idKey == null) {
      return null;
    }

    return fromData(<String, dynamic>{
      'type': type,
      idKey: id,
      if (deliveryId != null) 'notificationDeliveryId': deliveryId,
    });
  }

  static String? _readString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
