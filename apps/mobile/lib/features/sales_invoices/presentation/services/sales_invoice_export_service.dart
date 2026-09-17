import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../domain/sales_invoice.dart';

class SalesInvoiceExportService {
  const SalesInvoiceExportService();

  Future<Uint8List> buildPdf(SalesInvoiceDetails invoice) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf'),
    );
    final logo = await _logo(invoice);
    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final number = NumberFormat.decimalPattern('en');

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.Container(
                  width: 72,
                  height: 72,
                  child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
                ),
              pw.SizedBox(width: 14),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      invoice.sellerName,
                      style: pw.TextStyle(font: bold, fontSize: 18),
                    ),
                    if (invoice.sellerLegalName != null)
                      pw.Text(invoice.sellerLegalName!),
                    if (invoice.sellerAddress != null)
                      pw.Text('نشانی: ${invoice.sellerAddress}'),
                    if (invoice.sellerPhone != null)
                      pw.Text('تلفن: ${invoice.sellerPhone}'),
                    if (invoice.sellerNationalId != null)
                      pw.Text('شناسه ملی: ${invoice.sellerNationalId}'),
                    if (invoice.sellerEconomicCode != null)
                      pw.Text('کد اقتصادی: ${invoice.sellerEconomicCode}'),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              pw.Container(
                width: 145,
                padding: const pw.EdgeInsets.all(9),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey500),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('فاکتور فروش', style: pw.TextStyle(font: bold)),
                    pw.Text('شماره: ${invoice.invoiceNumber ?? '-'}'),
                    pw.Text('تاریخ: ${_jalali(invoice.issueDate)}'),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
            ),
            child: pw.Wrap(
              alignment: pw.WrapAlignment.end,
              spacing: 18,
              runSpacing: 5,
              children: [
                pw.Text('خریدار: ${invoice.buyerName}', style: pw.TextStyle(font: bold)),
                if (invoice.buyerNationalId != null)
                  pw.Text('کد/شناسه ملی: ${invoice.buyerNationalId}'),
                if (invoice.buyerPhone != null)
                  pw.Text('تلفن: ${invoice.buyerPhone}'),
                if (invoice.buyerAddress != null)
                  pw.Text('نشانی: ${invoice.buyerAddress}'),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const [
              'ردیف',
              'شرح دارو / کالا',
              'تعداد',
              'واحد',
              'فی (ریال)',
              'تخفیف',
              'جمع (ریال)',
            ],
            data: invoice.items.asMap().entries.map((entry) {
              final item = entry.value;
              return [
                '${entry.key + 1}',
                item.itemName,
                _quantity(item.quantity),
                item.unit ?? '-',
                number.format(double.parse(item.unitPrice)),
                number.format(double.parse(item.lineDiscount)),
                number.format(double.parse(item.lineTotal)),
              ];
            }).toList(growable: false),
            headerStyle: pw.TextStyle(font: bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerRight,
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          ),
          pw.SizedBox(height: 12),
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: 250,
              child: pw.Column(
                children: [
                  _totalRow('جمع اقلام', invoice.subtotal, number, bold),
                  _totalRow('تخفیف', invoice.discount, number, bold),
                  pw.Divider(),
                  _totalRow('مبلغ قابل پرداخت', invoice.payableAmount, number, bold, emphasized: true),
                ],
              ),
            ),
          ),
          if (invoice.notes != null) ...[
            pw.SizedBox(height: 10),
            pw.Text('توضیحات: ${invoice.notes}'),
          ],
          pw.SizedBox(height: 24),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              pw.Text('مهر و امضای فروشنده'),
              pw.Text('امضای خریدار'),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<void> sharePdf(SalesInvoiceDetails invoice) async {
    final bytes = await buildPdf(invoice);
    final fileName = _pdfName(invoice);
    final file = File(p.join((await getTemporaryDirectory()).path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        text: 'فاکتور فروش ${invoice.invoiceNumber ?? ''}',
      ),
    );
  }

  Future<bool> savePdf(SalesInvoiceDetails invoice) async {
    final bytes = await buildPdf(invoice);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'ذخیره فاکتور فروش',
      fileName: _pdfName(invoice),
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      bytes: bytes,
    );
    return path != null;
  }

  Future<Uint8List?> _logo(SalesInvoiceDetails invoice) async {
    final encoded = invoice.sellerLogoData;
    if (encoded != null) {
      try {
        return base64Decode(encoded.contains(',') ? encoded.split(',').last : encoded);
      } catch (_) {
        // Fall back to the bundled pharmacy logo.
      }
    }
    final data = await rootBundle.load('assets/branding/logo.png');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  pw.Widget _totalRow(
    String label,
    String raw,
    NumberFormat number,
    pw.Font bold, {
    bool emphasized = false,
  }) {
    final style = pw.TextStyle(
      font: emphasized ? bold : null,
      fontSize: emphasized ? 12 : 10,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('${number.format(double.parse(raw))} ریال', style: style),
          pw.Text(label, style: style),
        ],
      ),
    );
  }

  String _pdfName(SalesInvoiceDetails invoice) =>
      'sales_invoice_${invoice.invoiceNumber ?? invoice.id}.pdf';

  String _jalali(DateTime date) {
    final j = Jalali.fromDateTime(date.toLocal());
    return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}';
  }

  String _quantity(String raw) {
    final value = double.parse(raw);
    return value == value.roundToDouble() ? value.toInt().toString() : raw;
  }
}
