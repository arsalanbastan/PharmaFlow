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
import '../../../cheques/presentation/utils/cheque_text_utils.dart';

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

    final payable = double.parse(invoice.payableAmount).round();
    final payableWords = amountToPersianWords(payable);
    const receiptWidth = 80 * PdfPageFormat.mm;

    document.addPage(
      pw.MultiPage(
        pageFormat: const PdfPageFormat(
          receiptWidth,
          240 * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        build: (_) => [
          if (logo != null)
            pw.Center(
              child: pw.SizedBox(
                width: 34 * PdfPageFormat.mm,
                height: 24 * PdfPageFormat.mm,
                child: pw.Image(pw.MemoryImage(logo), fit: pw.BoxFit.contain),
              ),
            ),
          pw.Center(
            child: pw.Text(
              invoice.sellerName,
              style: pw.TextStyle(font: bold, fontSize: 13),
            ),
          ),
          if (invoice.sellerLegalName != null)
            pw.Center(
              child: pw.Text(
                invoice.sellerLegalName!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          pw.SizedBox(height: 4),
          pw.Table(
            border: pw.TableBorder.all(width: .55),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              _metaRow('تاریخ فاکتور', _jalali(invoice.issueDate)),
              _metaRow('شماره فاکتور', invoice.invoiceNumber ?? '-'),
              _metaRow('نوع نسخه', 'فروش دستی'),
              _metaRow('نام', invoice.buyerName),
              if (invoice.buyerPhone != null)
                _metaRow('تلفن', invoice.buyerPhone!),
            ],
          ),
          pw.Table(
            border: pw.TableBorder.all(width: .55),
            columnWidths: const {
              0: pw.FlexColumnWidth(5.2),
              1: pw.FlexColumnWidth(1.1),
              2: pw.FlexColumnWidth(2.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _receiptCell('شرح', bold: bold, centered: true),
                  _receiptCell('تعداد', bold: bold, centered: true),
                  _receiptCell('مبلغ', bold: bold, centered: true),
                ],
              ),
              ...invoice.items.map(
                (item) => pw.TableRow(
                  children: [
                    _receiptCell(
                      '${item.itemName}${item.unit == null ? '' : ' / ${item.unit}'}\nفی: ${number.format(double.parse(item.unitPrice))}',
                    ),
                    _receiptCell(_quantity(item.quantity), centered: true),
                    _receiptCell(
                      number.format(double.parse(item.lineTotal)),
                      centered: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: .55)),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(number.format(double.parse(invoice.subtotal))),
                pw.Text('قیمت کل اقلام:', style: pw.TextStyle(font: bold)),
              ],
            ),
          ),
          if (double.parse(invoice.discount) > 0)
            _receiptTotal('تخفیف:', invoice.discount, number, bold),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(5),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: .8)),
            child: pw.Column(
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      number.format(payable),
                      style: pw.TextStyle(font: bold, fontSize: 15),
                    ),
                    pw.Text(
                      'قابل پرداخت شد:',
                      style: pw.TextStyle(font: bold, fontSize: 14),
                    ),
                  ],
                ),
                if (payableWords != null)
                  pw.Text(
                    payableWords,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: 9),
                  ),
              ],
            ),
          ),
          if (invoice.notes != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text('توضیحات: ${invoice.notes}', style: const pw.TextStyle(fontSize: 8)),
            ),
          pw.SizedBox(height: 5),
          if (invoice.sellerAddress != null)
            pw.Center(
              child: pw.Text(
                invoice.sellerAddress!,
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          if (invoice.sellerPhone != null)
            pw.Center(
              child: pw.Text(
                invoice.sellerPhone!,
                style: pw.TextStyle(font: bold, fontSize: 11),
              ),
            ),
          if (invoice.buyerAddress != null)
            pw.Center(
              child: pw.Text(
                'نشانی خریدار: ${invoice.buyerAddress}',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(fontSize: 7),
              ),
            ),
        ],
      ),
    );

    return document.save();
  }

  pw.TableRow _metaRow(String label, String value) => pw.TableRow(
    children: [
      _receiptCell(value),
      _receiptCell('$label :', centered: false),
    ],
  );

  pw.Widget _receiptCell(
    String text, {
    pw.Font? bold,
    bool centered = false,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.all(3),
    child: pw.Text(
      text,
      textAlign: centered ? pw.TextAlign.center : pw.TextAlign.right,
      style: pw.TextStyle(font: bold, fontSize: 8),
    ),
  );

  pw.Widget _receiptTotal(
    String label,
    String raw,
    NumberFormat number,
    pw.Font bold,
  ) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    decoration: pw.BoxDecoration(border: pw.Border.all(width: .55)),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(number.format(double.parse(raw))),
        pw.Text(label, style: pw.TextStyle(font: bold)),
      ],
    ),
  );

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
        return base64Decode(
          encoded.contains(',') ? encoded.split(',').last : encoded,
        );
      } catch (_) {
        // Fall back to the bundled pharmacy logo.
      }
    }
    final data = await rootBundle.load('assets/branding/logo.png');
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
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
