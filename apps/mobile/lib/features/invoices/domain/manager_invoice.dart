class ManagerInvoiceCompany {
  const ManagerInvoiceCompany({required this.id, required this.name});

  final String id;
  final String name;

  factory ManagerInvoiceCompany.fromJson(Map<String, dynamic> json) {
    return ManagerInvoiceCompany(
      id: _requiredString(json['id'], 'company.id'),
      name: _requiredString(json['name'], 'company.name'),
    );
  }
}

class ManagerInvoiceSummary {
  const ManagerInvoiceSummary({
    required this.id,
    required this.arsenFactorId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.settlementDate,
    required this.factorDocTypeName,
    required this.factorPayablePrice,
    required this.paymentDays,
    required this.itemCount,
    required this.isDeletedInArsen,
    required this.isPaid,
    required this.company,
  });

  final String id;
  final int arsenFactorId;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? settlementDate;
  final String? factorDocTypeName;
  final String? factorPayablePrice;
  final int? paymentDays;
  final int itemCount;
  final bool isDeletedInArsen;
  final bool isPaid;
  final ManagerInvoiceCompany company;

  ManagerInvoiceSummary copyWith({bool? isPaid}) {
    return ManagerInvoiceSummary(
      id: id,
      arsenFactorId: arsenFactorId,
      invoiceNumber: invoiceNumber,
      invoiceDate: invoiceDate,
      settlementDate: settlementDate,
      factorDocTypeName: factorDocTypeName,
      factorPayablePrice: factorPayablePrice,
      paymentDays: paymentDays,
      itemCount: itemCount,
      isDeletedInArsen: isDeletedInArsen,
      isPaid: isPaid ?? this.isPaid,
      company: company,
    );
  }

  factory ManagerInvoiceSummary.fromJson(Map<String, dynamic> json) {
    final rawCompany = json['company'];

    if (rawCompany is! Map<String, dynamic>) {
      throw const FormatException('Invoice company is invalid.');
    }

    return ManagerInvoiceSummary(
      id: _requiredString(json['id'], 'invoice.id'),
      arsenFactorId: _requiredInt(json['arsenFactorId'], 'arsenFactorId'),
      invoiceNumber: _optionalString(json['invoiceNumber']),
      invoiceDate: _optionalString(json['invoiceDate']),
      settlementDate: _optionalString(json['settlementDate']),
      factorDocTypeName: _optionalString(json['factorDocTypeName']),
      factorPayablePrice: _decimalString(json['factorPayablePrice']),
      paymentDays: _optionalInt(json['paymentDays']),
      itemCount: _optionalInt(json['itemCount']) ?? 0,
      isDeletedInArsen: json['isDeletedInArsen'] == true,
      isPaid: json['isPaid'] == true,
      company: ManagerInvoiceCompany.fromJson(rawCompany),
    );
  }
}

class ManagerInvoicePage {
  const ManagerInvoicePage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  final List<ManagerInvoiceSummary> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  factory ManagerInvoicePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    if (rawItems is! List<dynamic>) {
      throw const FormatException('Invoice list is invalid.');
    }

    return ManagerInvoicePage(
      items: rawItems
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invoice row is invalid.');
            }

            return ManagerInvoiceSummary.fromJson(raw);
          })
          .toList(growable: false),
      page: _requiredInt(json['page'], 'page'),
      pageSize: _requiredInt(json['pageSize'], 'pageSize'),
      totalCount: _requiredInt(json['totalCount'], 'totalCount'),
      totalPages: _requiredInt(json['totalPages'], 'totalPages'),
    );
  }
}

class ManagerInvoiceItem {
  const ManagerInvoiceItem({
    required this.id,
    required this.arsenDrugId,
    required this.drugName,
    required this.barcode,
    required this.packetQuantity,
    required this.quantity,
    required this.salePrice,
    required this.purchasePrice,
    required this.rowDiscount,
    required this.hasTax,
    required this.expireDate,
    required this.batchNumber,
  });

  final String id;
  final String? arsenDrugId;
  final String? drugName;
  final String? barcode;
  final int? packetQuantity;
  final double? quantity;
  final String? salePrice;
  final String? purchasePrice;
  final String? rowDiscount;
  final int? hasTax;
  final String? expireDate;
  final String? batchNumber;

  factory ManagerInvoiceItem.fromJson(Map<String, dynamic> json) {
    return ManagerInvoiceItem(
      id: _requiredString(json['id'], 'invoiceItem.id'),
      arsenDrugId: _optionalString(json['arsenDrugId']),
      drugName: _optionalString(json['drugName']),
      barcode: _optionalString(json['barcode']),
      packetQuantity: _optionalInt(json['packetQuantity']),
      quantity: _optionalDouble(json['quantity']),
      salePrice: _decimalString(json['salePrice']),
      purchasePrice: _decimalString(json['purchasePrice']),
      rowDiscount: _decimalString(json['rowDiscount']),
      hasTax: _optionalInt(json['hasTax']),
      expireDate: _optionalString(json['expireDate']),
      batchNumber: _optionalString(json['batchNumber']),
    );
  }
}

class ManagerInvoiceDetails {
  const ManagerInvoiceDetails({
    required this.id,
    required this.arsenFactorId,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.docDate,
    required this.settlementDate,
    required this.description,
    required this.factorDocTypeName,
    required this.factorTypeName,
    required this.arsenBusinessPartnerName,
    required this.factorTotalPrice,
    required this.factorDiscount,
    required this.factorTax,
    required this.factorPayablePrice,
    required this.barbariPrice,
    required this.paymentDays,
    required this.itemCount,
    required this.isDeletedInArsen,
    required this.isPaid,
    required this.company,
    required this.items,
  });

  final String id;
  final int arsenFactorId;
  final String? invoiceNumber;
  final String? invoiceDate;
  final String? docDate;
  final String? settlementDate;
  final String? description;
  final String? factorDocTypeName;
  final String? factorTypeName;
  final String? arsenBusinessPartnerName;
  final String? factorTotalPrice;
  final String? factorDiscount;
  final String? factorTax;
  final String? factorPayablePrice;
  final String? barbariPrice;
  final int? paymentDays;
  final int itemCount;
  final bool isDeletedInArsen;
  final bool isPaid;
  final ManagerInvoiceCompany company;
  final List<ManagerInvoiceItem> items;

  factory ManagerInvoiceDetails.fromJson(Map<String, dynamic> json) {
    final rawCompany = json['company'];
    final rawItems = json['items'];

    if (rawCompany is! Map<String, dynamic>) {
      throw const FormatException('Invoice company is invalid.');
    }

    if (rawItems is! List<dynamic>) {
      throw const FormatException('Invoice items are invalid.');
    }

    return ManagerInvoiceDetails(
      id: _requiredString(json['id'], 'invoice.id'),
      arsenFactorId: _requiredInt(json['arsenFactorId'], 'arsenFactorId'),
      invoiceNumber: _optionalString(json['invoiceNumber']),
      invoiceDate: _optionalString(json['invoiceDate']),
      docDate: _optionalString(json['docDate']),
      settlementDate: _optionalString(json['settlementDate']),
      description: _optionalString(json['description']),
      factorDocTypeName: _optionalString(json['factorDocTypeName']),
      factorTypeName: _optionalString(json['factorTypeName']),
      arsenBusinessPartnerName: _optionalString(
        json['arsenBusinessPartnerName'],
      ),
      factorTotalPrice: _decimalString(json['factorTotalPrice']),
      factorDiscount: _decimalString(json['factorDiscount']),
      factorTax: _decimalString(json['factorTax']),
      factorPayablePrice: _decimalString(json['factorPayablePrice']),
      barbariPrice: _decimalString(json['barbariPrice']),
      paymentDays: _optionalInt(json['paymentDays']),
      itemCount: _optionalInt(json['itemCount']) ?? 0,
      isDeletedInArsen: json['isDeletedInArsen'] == true,
      isPaid: json['isPaid'] == true,
      company: ManagerInvoiceCompany.fromJson(rawCompany),
      items: rawItems
          .map((raw) {
            if (raw is! Map<String, dynamic>) {
              throw const FormatException('Invoice item is invalid.');
            }

            return ManagerInvoiceItem.fromJson(raw);
          })
          .toList(growable: false),
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

String? _decimalString(Object? value) {
  return _optionalString(value);
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

double? _optionalDouble(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString());
}
