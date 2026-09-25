class SalesInvoiceProfile {
  const SalesInvoiceProfile({
    required this.sellerName,
    required this.legalName,
    required this.nationalId,
    required this.economicCode,
    required this.phone,
    required this.address,
    required this.logoData,
  });

  final String sellerName;
  final String? legalName;
  final String? nationalId;
  final String? economicCode;
  final String? phone;
  final String? address;
  final String? logoData;

  factory SalesInvoiceProfile.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceProfile(
      sellerName: _requiredText(json['sellerName'], 'sellerName'),
      legalName: _optionalText(json['legalName']),
      nationalId: _optionalText(json['nationalId']),
      economicCode: _optionalText(json['economicCode']),
      phone: _optionalText(json['phone']),
      address: _optionalText(json['address']),
      logoData: _optionalText(json['logoData']),
    );
  }
}

class SalesInvoiceSummary {
  const SalesInvoiceSummary({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.buyerName,
    required this.buyerPhone,
    required this.payableAmount,
    required this.itemCount,
    required this.status,
  });

  final String id;
  final String? invoiceNumber;
  final DateTime issueDate;
  final String buyerName;
  final String? buyerPhone;
  final String payableAmount;
  final int itemCount;
  final String status;

  factory SalesInvoiceSummary.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceSummary(
      id: _requiredText(json['id'], 'id'),
      invoiceNumber: _optionalText(json['invoiceNumber']),
      issueDate: DateTime.parse(_requiredText(json['issueDate'], 'issueDate')),
      buyerName: _optionalText(json['buyerName']) ?? '',
      buyerPhone: _optionalText(json['buyerPhone']),
      payableAmount: _requiredText(json['payableAmount'], 'payableAmount'),
      itemCount: _int(json['itemCount']),
      status: _optionalText(json['status']) ?? 'ISSUED',
    );
  }
}

class SalesInvoicePage {
  const SalesInvoicePage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalCount,
  });

  final List<SalesInvoiceSummary> items;
  final int page;
  final int totalPages;
  final int totalCount;

  factory SalesInvoicePage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException('Sales invoice list is invalid.');
    }
    return SalesInvoicePage(
      items: rawItems
          .map(
            (raw) => SalesInvoiceSummary.fromJson(raw as Map<String, dynamic>),
          )
          .toList(growable: false),
      page: _int(json['page']),
      totalPages: _int(json['totalPages']),
      totalCount: _int(json['totalCount']),
    );
  }
}

class SalesInvoiceItem {
  const SalesInvoiceItem({
    required this.id,
    required this.catalogItemId,
    required this.itemName,
    required this.barcode,
    required this.unit,
    required this.quantity,
    required this.unitPrice,
    required this.lineDiscount,
    required this.lineTotal,
  });

  final String id;
  final String? catalogItemId;
  final String itemName;
  final String? barcode;
  final String? unit;
  final String quantity;
  final String unitPrice;
  final String lineDiscount;
  final String lineTotal;

  factory SalesInvoiceItem.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceItem(
      id: _requiredText(json['id'], 'item.id'),
      catalogItemId: _optionalText(json['catalogItemId']),
      itemName: _requiredText(json['itemName'], 'itemName'),
      barcode: _optionalText(json['barcode']),
      unit: _optionalText(json['unit']),
      quantity: _requiredText(json['quantity'], 'quantity'),
      unitPrice: _requiredText(json['unitPrice'], 'unitPrice'),
      lineDiscount: _requiredText(json['lineDiscount'], 'lineDiscount'),
      lineTotal: _requiredText(json['lineTotal'], 'lineTotal'),
    );
  }
}

class SalesInvoiceDetails {
  const SalesInvoiceDetails({
    required this.id,
    required this.invoiceNumber,
    required this.issueDate,
    required this.buyerName,
    required this.buyerNationalId,
    required this.buyerPhone,
    required this.buyerAddress,
    required this.sellerName,
    required this.sellerLegalName,
    required this.sellerNationalId,
    required this.sellerEconomicCode,
    required this.sellerPhone,
    required this.sellerAddress,
    required this.sellerLogoData,
    required this.subtotal,
    required this.discount,
    required this.payableAmount,
    required this.notes,
    required this.items,
  });

  final String id;
  final String? invoiceNumber;
  final DateTime issueDate;
  final String buyerName;
  final String? buyerNationalId;
  final String? buyerPhone;
  final String? buyerAddress;
  final String sellerName;
  final String? sellerLegalName;
  final String? sellerNationalId;
  final String? sellerEconomicCode;
  final String? sellerPhone;
  final String? sellerAddress;
  final String? sellerLogoData;
  final String subtotal;
  final String discount;
  final String payableAmount;
  final String? notes;
  final List<SalesInvoiceItem> items;

  factory SalesInvoiceDetails.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException('Sales invoice items are invalid.');
    }
    return SalesInvoiceDetails(
      id: _requiredText(json['id'], 'id'),
      invoiceNumber: _optionalText(json['invoiceNumber']),
      issueDate: DateTime.parse(_requiredText(json['issueDate'], 'issueDate')),
      buyerName: _optionalText(json['buyerName']) ?? '',
      buyerNationalId: _optionalText(json['buyerNationalId']),
      buyerPhone: _optionalText(json['buyerPhone']),
      buyerAddress: _optionalText(json['buyerAddress']),
      sellerName: _requiredText(json['sellerName'], 'sellerName'),
      sellerLegalName: _optionalText(json['sellerLegalName']),
      sellerNationalId: _optionalText(json['sellerNationalId']),
      sellerEconomicCode: _optionalText(json['sellerEconomicCode']),
      sellerPhone: _optionalText(json['sellerPhone']),
      sellerAddress: _optionalText(json['sellerAddress']),
      sellerLogoData: _optionalText(json['sellerLogoData']),
      subtotal: _requiredText(json['subtotal'], 'subtotal'),
      discount: _requiredText(json['discount'], 'discount'),
      payableAmount: _requiredText(json['payableAmount'], 'payableAmount'),
      notes: _optionalText(json['notes']),
      items: rawItems
          .map((raw) => SalesInvoiceItem.fromJson(raw as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

String _requiredText(Object? value, String field) {
  final text = _optionalText(value);
  if (text == null) {
    throw FormatException('$field is missing.');
  }
  return text;
}

String? _optionalText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse(value.toString());
}
