class ManagerCatalogSummary {
  const ManagerCatalogSummary({
    required this.id,
    required this.arsenDrugId,
    required this.category,
    required this.persianName,
    required this.genericName,
    required this.persianBrandName,
    required this.brandName,
    required this.unit,
    required this.shapeName,
    required this.packetQuantity,
    required this.salesPrice,
    required this.lastPurchasePrice,
    required this.isActive,
    required this.sourceSyncedAt,
  });

  final String id;
  final String arsenDrugId;
  final String category;

  final String? persianName;
  final String? genericName;
  final String? persianBrandName;
  final String? brandName;

  final String? unit;
  final String? shapeName;

  final int? packetQuantity;
  final String? salesPrice;
  final String? lastPurchasePrice;

  final bool isActive;
  final String? sourceSyncedAt;

  String get displayName {
    return persianName ??
        persianBrandName ??
        brandName ??
        genericName ??
        'کد آرسن $arsenDrugId';
  }

  factory ManagerCatalogSummary.fromJson(Map<String, dynamic> json) {
    return ManagerCatalogSummary(
      id: _requiredString(json['id'], 'catalog.id'),
      arsenDrugId: _requiredString(json['arsenDrugId'], 'arsenDrugId'),
      category: _requiredString(json['category'], 'category'),
      persianName: _optionalString(json['persianName']),
      genericName: _optionalString(json['genericName']),
      persianBrandName: _optionalString(json['persianBrandName']),
      brandName: _optionalString(json['brandName']),
      unit: _optionalString(json['unit']),
      shapeName: _optionalString(json['shapeName']),
      packetQuantity: _optionalInt(json['packetQuantity']),
      salesPrice: _optionalString(json['salesPrice']),
      lastPurchasePrice: _optionalString(json['lastPurchasePrice']),
      isActive: json['isActive'] == true,
      sourceSyncedAt: _optionalString(json['sourceSyncedAt']),
    );
  }
}

class ManagerCatalogPage {
  const ManagerCatalogPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<ManagerCatalogSummary> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  factory ManagerCatalogPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List<dynamic>) {
      throw const FormatException('Catalog items are invalid.');
    }

    return ManagerCatalogPage(
      items: rawItems
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Catalog row is invalid.');
            }

            return ManagerCatalogSummary.fromJson(raw);
          })
          .toList(growable: false),
      page: _requiredInt(json['page'], 'page'),
      pageSize: _requiredInt(json['pageSize'], 'pageSize'),
      totalCount: _requiredInt(json['totalCount'], 'totalCount'),
      totalPages: _requiredInt(json['totalPages'], 'totalPages'),
    );
  }
}

class ManagerCatalogDetails {
  const ManagerCatalogDetails({
    required this.id,
    required this.arsenDrugId,
    required this.category,
    required this.persianName,
    required this.genericName,
    required this.persianBrandName,
    required this.brandName,
    required this.unit,
    required this.shapeName,
    required this.packetQuantity,
    required this.salesPrice,
    required this.lastPurchasePrice,
    required this.isActive,
    required this.description,
    required this.importedAt,
    required this.sourceSyncedAt,
  });

  final String id;
  final String arsenDrugId;
  final String category;

  final String? persianName;
  final String? genericName;
  final String? persianBrandName;
  final String? brandName;

  final String? unit;
  final String? shapeName;

  final int? packetQuantity;
  final String? salesPrice;
  final String? lastPurchasePrice;

  final bool isActive;
  final String? description;

  final String? importedAt;
  final String? sourceSyncedAt;

  String get displayName {
    return persianName ??
        persianBrandName ??
        brandName ??
        genericName ??
        'کد آرسن $arsenDrugId';
  }

  factory ManagerCatalogDetails.fromJson(Map<String, dynamic> json) {
    return ManagerCatalogDetails(
      id: _requiredString(json['id'], 'catalog.id'),
      arsenDrugId: _requiredString(json['arsenDrugId'], 'arsenDrugId'),
      category: _requiredString(json['category'], 'category'),
      persianName: _optionalString(json['persianName']),
      genericName: _optionalString(json['genericName']),
      persianBrandName: _optionalString(json['persianBrandName']),
      brandName: _optionalString(json['brandName']),
      unit: _optionalString(json['unit']),
      shapeName: _optionalString(json['shapeName']),
      packetQuantity: _optionalInt(json['packetQuantity']),
      salesPrice: _optionalString(json['salesPrice']),
      lastPurchasePrice: _optionalString(json['lastPurchasePrice']),
      isActive: json['isActive'] == true,
      description: _optionalString(json['description']),
      importedAt: _optionalString(json['importedAt']),
      sourceSyncedAt: _optionalString(json['sourceSyncedAt']),
    );
  }
}

String _requiredString(Object? value, String field) {
  final result = _optionalString(value);

  if (result == null) {
    throw FormatException('$field is missing.');
  }

  return result;
}

String? _optionalString(Object? value) {
  if (value == null) {
    return null;
  }

  final normalized = value.toString().trim();

  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Object? value, String field) {
  final result = _optionalInt(value);

  if (result == null) {
    throw FormatException('$field is invalid.');
  }

  return result;
}

int? _optionalInt(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}
