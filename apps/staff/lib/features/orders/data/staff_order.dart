class StaffOrder {
  const StaffOrder({
    required this.id,
    required this.category,
    required this.itemText,
    required this.status,
    required this.requestedByName,
    required this.createdAt,
    this.requestedByUserId,
    this.requestedQuantity,
    this.orderedQuantity,
    this.suggestedCompanyText,
    this.notes,
    this.assignedCompanyName,
    this.orderedAt,
  });

  final String id;
  final String category;
  final String itemText;
  final String status;
  final String requestedByName;
  final String? requestedByUserId;
  final DateTime createdAt;
  final int? requestedQuantity;
  final int? orderedQuantity;
  final String? suggestedCompanyText;
  final String? notes;
  final String? assignedCompanyName;
  final DateTime? orderedAt;

  bool get isPending => status == 'PENDING';

  bool get isOrdered => status == 'ORDERED';

  bool get canBeChangedByStaff => isPending;

  String get categoryLabel => category == 'GOODS' ? 'کالا' : 'دارو';

  factory StaffOrder.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final category = json['category']?.toString().trim() ?? '';
    final itemText = json['itemText']?.toString().trim() ?? '';
    final status = json['status']?.toString().trim() ?? '';
    final requestedByName = json['requestedByName']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(
      json['createdAt']?.toString().trim() ?? '',
    );

    if (id.isEmpty ||
        category.isEmpty ||
        itemText.isEmpty ||
        status.isEmpty ||
        requestedByName.isEmpty ||
        createdAt == null) {
      throw const FormatException('Order list item is incomplete.');
    }

    String? assignedCompanyName;
    final assignedCompany = json['assignedCompany'];

    if (assignedCompany is Map) {
      assignedCompanyName = _nullIfBlank(assignedCompany['name']);
    }

    return StaffOrder(
      id: id,
      category: category,
      itemText: itemText,
      status: status,
      requestedByName: requestedByName,
      requestedByUserId: _nullIfBlank(json['requestedByUserId']),
      createdAt: createdAt,
      requestedQuantity: _toNullableInt(json['requestedQuantity']),
      orderedQuantity: _toNullableInt(json['orderedQuantity']),
      suggestedCompanyText: _nullIfBlank(json['suggestedCompanyText']),
      notes: _nullIfBlank(json['notes']),
      assignedCompanyName: assignedCompanyName,
      orderedAt: DateTime.tryParse(json['orderedAt']?.toString() ?? ''),
    );
  }

  static int? _toNullableInt(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }

  static String? _nullIfBlank(Object? value) {
    final normalized = value?.toString().trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
