class ManagerOrder {
  const ManagerOrder({
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
    this.assignedCompanyId,
    this.assignedCompanyName,
    this.hasPhoto = false,
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
  final String? requestedByUserId;
  final DateTime createdAt;
  final String? assignedCompanyId;
  final String? assignedCompanyName;
  final bool hasPhoto;

  bool get isPending => status == 'PENDING';

  factory ManagerOrder.fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    final category = _requiredString(json, 'category');
    final itemText = _requiredString(json, 'itemText');
    final status = _requiredString(json, 'status');
    final requestedByName = _requiredString(json, 'requestedByName');
    final createdAtRaw = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtRaw);

    if (createdAt == null) {
      throw const FormatException('Order createdAt is not a valid date.');
    }

    final assignedCompanyRaw = json['assignedCompany'];
    String? assignedCompanyId;
    String? assignedCompanyName;

    if (assignedCompanyRaw is Map<String, dynamic>) {
      assignedCompanyId = _optionalString(assignedCompanyRaw['id']);
      assignedCompanyName = _optionalString(assignedCompanyRaw['name']);
    }

    return ManagerOrder(
      id: id,
      category: category,
      itemText: itemText,
      requestedQuantity: _optionalInt(
        json['requestedQuantity'],
        'requestedQuantity',
      ),
      orderedQuantity: _optionalInt(json['orderedQuantity'], 'orderedQuantity'),
      suggestedCompanyText: _optionalString(json['suggestedCompanyText']),
      notes: _optionalString(json['notes']),
      status: status,
      possibleDuplicate: json['possibleDuplicate'] == true,
      requestedByName: requestedByName,
      requestedByUserId: _optionalString(json['requestedByUserId']),
      createdAt: createdAt,
      assignedCompanyId: assignedCompanyId,
      assignedCompanyName: assignedCompanyName,
      hasPhoto:
          _optionalString(json['photoStorageKey']) != null &&
          json['photoDeletedAt'] == null,
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = _optionalString(json[key]);

    if (value == null) {
      throw FormatException('Order field $key is missing.');
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

    throw FormatException('Order $fieldName is invalid.');
  }

  static String? _optionalString(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
