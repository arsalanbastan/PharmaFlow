class ManagerOrderDetails {
  const ManagerOrderDetails({
    required this.id,
    required this.category,
    required this.itemText,
    required this.status,
    required this.possibleDuplicate,
    required this.requestedByName,
    required this.createdAt,
    this.requestedQuantity,
    this.orderedQuantity,
    this.suggestedCompanyText,
    this.notes,
    this.requestedByUserId,
    this.orderedByName,
    this.receivedByName,
    this.canceledByName,
    this.deletedByName,
    this.orderedByUserId,
    this.receivedByUserId,
    this.canceledByUserId,
    this.deletedByUserId,
    this.updatedAt,
    this.orderedAt,
    this.receivedAt,
    this.canceledAt,
    this.deletedAt,
    this.photoStorageKey,
    this.photoFileSize,
    this.photoSha256,
    this.photoDeletedAt,
    this.assignedCompanyId,
    this.assignedCompanyName,
  });

  final String id;
  final String category;
  final String itemText;
  final int? requestedQuantity;
  final int? orderedQuantity;
  final String? suggestedCompanyText;
  final String? notes;
  final String status;
  final bool possibleDuplicate;

  final String requestedByName;
  final String? orderedByName;
  final String? receivedByName;
  final String? canceledByName;
  final String? deletedByName;

  final String? requestedByUserId;
  final String? orderedByUserId;
  final String? receivedByUserId;
  final String? canceledByUserId;
  final String? deletedByUserId;

  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? orderedAt;
  final DateTime? receivedAt;
  final DateTime? canceledAt;
  final DateTime? deletedAt;

  final String? photoStorageKey;
  final int? photoFileSize;
  final String? photoSha256;
  final DateTime? photoDeletedAt;

  final String? assignedCompanyId;
  final String? assignedCompanyName;

  bool get photoWasDeleted => photoDeletedAt != null;

  factory ManagerOrderDetails.fromJson(Map<String, dynamic> json) {
    final assignedCompanyRaw = json['assignedCompany'];
    String? assignedCompanyId;
    String? assignedCompanyName;

    if (assignedCompanyRaw is Map<String, dynamic>) {
      assignedCompanyId = _optionalString(assignedCompanyRaw['id']);
      assignedCompanyName = _optionalString(assignedCompanyRaw['name']);
    }

    return ManagerOrderDetails(
      id: _requiredString(json, 'id'),
      category: _requiredString(json, 'category'),
      itemText: _requiredString(json, 'itemText'),
      requestedQuantity: _optionalInt(
        json['requestedQuantity'],
        'requestedQuantity',
      ),
      orderedQuantity: _optionalInt(json['orderedQuantity'], 'orderedQuantity'),
      suggestedCompanyText: _optionalString(json['suggestedCompanyText']),
      notes: _optionalString(json['notes']),
      status: _requiredString(json, 'status'),
      possibleDuplicate: json['possibleDuplicate'] == true,
      requestedByName: _requiredString(json, 'requestedByName'),
      requestedByUserId: _optionalString(json['requestedByUserId']),
      orderedByName: _optionalString(json['orderedByName']),
      receivedByName: _optionalString(json['receivedByName']),
      canceledByName: _optionalString(json['canceledByName']),
      deletedByName: _optionalString(json['deletedByName']),
      orderedByUserId: _optionalString(json['orderedByUserId']),
      receivedByUserId: _optionalString(json['receivedByUserId']),
      canceledByUserId: _optionalString(json['canceledByUserId']),
      deletedByUserId: _optionalString(json['deletedByUserId']),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _optionalDateTime(json['updatedAt'], 'updatedAt'),
      orderedAt: _optionalDateTime(json['orderedAt'], 'orderedAt'),
      receivedAt: _optionalDateTime(json['receivedAt'], 'receivedAt'),
      canceledAt: _optionalDateTime(json['canceledAt'], 'canceledAt'),
      deletedAt: _optionalDateTime(json['deletedAt'], 'deletedAt'),
      photoStorageKey: _optionalString(json['photoStorageKey']),
      photoFileSize: _optionalInt(json['photoFileSize'], 'photoFileSize'),
      photoSha256: _optionalString(json['photoSha256']),
      photoDeletedAt: _optionalDateTime(
        json['photoDeletedAt'],
        'photoDeletedAt',
      ),
      assignedCompanyId: assignedCompanyId,
      assignedCompanyName: assignedCompanyName,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _optionalString(json[key]);

    if (value == null) {
      throw FormatException('Order detail field $key is missing.');
    }

    return value;
  }

  static DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
    final value = _optionalDateTime(json[key], key);

    if (value == null) {
      throw FormatException('Order detail field $key is missing.');
    }

    return value;
  }

  static DateTime? _optionalDateTime(Object? value, String fieldName) {
    if (value == null) {
      return null;
    }

    if (value is! String) {
      throw FormatException('Order detail $fieldName is invalid.');
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      throw FormatException('Order detail $fieldName is invalid.');
    }

    return parsed;
  }

  static int? _optionalInt(Object? value, String fieldName) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    throw FormatException('Order detail $fieldName is invalid.');
  }

  static String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class ManagerOrderPhoto {
  const ManagerOrderPhoto({
    required this.orderId,
    required this.downloadUrl,
    this.fileSize,
    this.sha256,
    this.expiresInSeconds,
  });

  final String orderId;
  final String downloadUrl;
  final int? fileSize;
  final String? sha256;
  final int? expiresInSeconds;

  factory ManagerOrderPhoto.fromJson(Map<String, dynamic> json) {
    return ManagerOrderPhoto(
      orderId: _requiredString(json, 'orderId'),
      downloadUrl: _requiredString(json, 'downloadUrl'),
      fileSize: _optionalInt(json['fileSize'], 'fileSize'),
      sha256: _optionalString(json['sha256']),
      expiresInSeconds: _optionalInt(
        json['expiresInSeconds'],
        'expiresInSeconds',
      ),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _optionalString(json[key]);

    if (value == null) {
      throw FormatException('Order photo field $key is missing.');
    }

    return value;
  }

  static int? _optionalInt(Object? value, String fieldName) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    throw FormatException('Order photo $fieldName is invalid.');
  }

  static String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
