import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow_staff/features/sales_invoices/sales_invoice.dart';

void main() {
  test('a saved invoice with no buyer name can be read from the API', () {
    final invoice = SalesInvoiceDetails.fromJson({
      'id': 'invoice-1',
      'invoiceNumber': 'PF-00001',
      'issueDate': '2026-09-25T00:00:00.000Z',
      'buyerName': '',
      'sellerName': 'داروخانه',
      'subtotal': '100',
      'discount': '0',
      'payableAmount': '100',
      'items': <Map<String, dynamic>>[],
    });
    expect(invoice.buyerName, isEmpty);

    final summary = SalesInvoiceSummary.fromJson({
      'id': 'invoice-1',
      'invoiceNumber': 'PF-00001',
      'issueDate': '2026-09-25T00:00:00.000Z',
      'buyerName': '',
      'payableAmount': '100',
      'itemCount': 0,
    });
    expect(summary.buyerName, isEmpty);
  });
}
