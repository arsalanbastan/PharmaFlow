import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/features/invoices/domain/manager_invoice.dart';
import 'package:pharmaflow/features/invoices/domain/manager_invoice_settlement.dart';
import 'package:pharmaflow/features/sales_invoices/domain/sales_invoice.dart';

void main() {
  group('manager invoice payment models', () {
    test('reads a partially settled invoice returned by the API', () {
      final invoice = ManagerInvoiceSummary.fromJson(<String, dynamic>{
        'id': '5a3c8c61-738d-41e4-9daa-5f4f5964b659',
        'arsenFactorId': 1201,
        'invoiceNumber': 'A-1201',
        'invoiceDate': '1405/06/27',
        'factorDocType': 1,
        'factorPayablePrice': '1000000',
        'itemCount': 4,
        'isDeletedInArsen': false,
        'isPaid': false,
        'paidAmount': '600000',
        'discountAmount': '100000',
        'settledAmount': '700000',
        'remainingAmount': '300000',
        'paymentStatus': 'PARTIAL',
        'company': <String, dynamic>{
          'id': '52d544b7-8567-4a74-9367-beb10a45ddcd',
          'name': 'شرکت الیت',
        },
      });

      expect(invoice.paymentStatus, 'PARTIAL');
      expect(invoice.paidAmount, '600000');
      expect(invoice.discountAmount, '100000');
      expect(invoice.remainingAmount, '300000');
      expect(invoice.company.name, 'شرکت الیت');
    });

    test('reads settlement preparation with selectable bank accounts', () {
      final preparation = InvoiceSettlementPreparation.fromJson(
        <String, dynamic>{
          'company': <String, dynamic>{
            'id': '52d544b7-8567-4a74-9367-beb10a45ddcd',
            'name': 'شرکت الیت',
          },
          'totalRemainingAmount': '300000',
          'invoices': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '5a3c8c61-738d-41e4-9daa-5f4f5964b659',
              'invoiceNumber': 'A-1201',
              'invoiceDate': '1405/06/27',
              'factorPayablePrice': '1000000',
              'paidAmount': '600000',
              'discountAmount': '100000',
              'remainingAmount': '300000',
            },
          ],
          'bankAccounts': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'e2520178-9f4e-4ee3-a69c-053250fbc20b',
              'bankName': 'ملت',
              'accountTitle': 'حساب جاری',
              'accountNumber': '123',
            },
          ],
        },
      );

      expect(preparation.totalRemainingAmount, '300000');
      expect(preparation.invoices, hasLength(1));
      expect(preparation.bankAccounts.single.displayName, 'ملت — حساب جاری');
    });
  });

  test('reads a persisted sales invoice snapshot', () {
    final invoice = SalesInvoiceDetails.fromJson(<String, dynamic>{
      'id': 'f297a3f5-d8a2-47f2-a560-8aabde3c54ae',
      'invoiceNumber': 'PF-00000012',
      'issueDate': '2026-09-17T00:00:00.000Z',
      'buyerName': 'خریدار آزمایشی',
      'sellerName': 'داروخانه دکتر خسروانی',
      'subtotal': '250000',
      'discount': '50000',
      'payableAmount': '200000',
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': '69400865-a2ed-4b97-bbbf-08cb52ec7211',
          'catalogItemId': 'b88964c8-6950-42d5-956f-f56bf2fe0186',
          'itemName': 'کالای آزمایشی',
          'quantity': '2',
          'unitPrice': '125000',
          'lineDiscount': '0',
          'lineTotal': '250000',
        },
      ],
    });

    expect(invoice.invoiceNumber, 'PF-00000012');
    expect(invoice.sellerName, 'داروخانه دکتر خسروانی');
    expect(invoice.payableAmount, '200000');
    expect(invoice.items.single.itemName, 'کالای آزمایشی');
  });
}
