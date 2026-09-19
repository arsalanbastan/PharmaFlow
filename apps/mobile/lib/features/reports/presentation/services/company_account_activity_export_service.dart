import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../models/company_account_activity_report_data.dart';

class CompanyAccountActivityExportService {
  const CompanyAccountActivityExportService();

  Future<void> shareExcel({
    required String companyName,
    required List<CompanyAccountActivityRow> rows,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['گردش حساب'];

    final totalCheques = _sumByKind(rows, CompanyAccountActivityKind.cheque);
    final totalCashPayments = _sumByKind(
      rows,
      CompanyAccountActivityKind.cashPayment,
    );

    sheet.appendRow([
      TextCellValue('گردش حساب طرف حساب'),
      TextCellValue(companyName),
    ]);

    sheet.appendRow([
      TextCellValue('جمع چک‌ها'),
      IntCellValue(totalCheques),
      TextCellValue('جمع واریزی‌ها'),
      IntCellValue(totalCashPayments),
      TextCellValue('جمع کل پرداخت‌ها'),
      IntCellValue(totalCheques + totalCashPayments),
    ]);

    sheet.appendRow([
      TextCellValue('تاریخ'),
      TextCellValue('نوع تراکنش'),
      TextCellValue('مبلغ (ریال)'),
      TextCellValue('شماره چک / پیگیری'),
      TextCellValue('روش'),
      TextCellValue('توضیحات'),
    ]);

    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(_formatJalali(row.effectiveDate)),
        TextCellValue(row.typeLabel),
        IntCellValue(row.amountRial),
        TextCellValue(row.reference),
        TextCellValue(row.method),
        TextCellValue(row.description),
      ]);
    }

    final bytes = excel.encode();

    if (bytes == null || bytes.isEmpty) {
      throw StateError('ساخت فایل Excel با خطا مواجه شد.');
    }

    final fileName =
        'pharmaflow_company_activity_${_safeName(companyName)}_${_fileStamp()}.xlsx';

    final file = File(p.join((await getTemporaryDirectory()).path, fileName));

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        fileNameOverrides: [fileName],
        text: 'گردش حساب $companyName',
      ),
    );
  }

  Future<void> sharePdf({
    required String companyName,
    required List<CompanyAccountActivityRow> rows,
  }) async {
    final regularData = await rootBundle.load(
      'assets/fonts/Vazirmatn-Regular.ttf',
    );

    final boldData = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');

    final regularFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final totalCheques = _sumByKind(rows, CompanyAccountActivityKind.cheque);

    final totalCashPayments = _sumByKind(
      rows,
      CompanyAccountActivityKind.cashPayment,
    );

    final numberFormat = NumberFormat.decimalPattern('en');

    final document = pw.Document(
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Text(
                    'گزارش گردش حساب طرف حساب',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    companyName,
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 12),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                      borderRadius: const pw.BorderRadius.all(
                        pw.Radius.circular(4),
                      ),
                    ),
                    child: pw.Text(
                      'جمع چک‌ها: ${numberFormat.format(totalCheques)} ریال    '
                      'جمع واریزی‌ها: ${numberFormat.format(totalCashPayments)} ریال    '
                      'جمع کل پرداخت‌ها: ${numberFormat.format(totalCheques + totalCashPayments)} ریال',
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildTable(
                    rows: rows,
                    numberFormat: numberFormat,
                    boldFont: boldFont,
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await document.save();

    final fileName =
        'pharmaflow_company_activity_${_safeName(companyName)}_${_fileStamp()}.pdf';

    final file = File(p.join((await getTemporaryDirectory()).path, fileName));

    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        text: 'گردش حساب $companyName',
      ),
    );
  }

  pw.Widget _buildTable({
    required List<CompanyAccountActivityRow> rows,
    required NumberFormat numberFormat,
    required pw.Font boldFont,
  }) {
    final headerValues = [
      'تاریخ',
      'نوع',
      'مبلغ (ریال)',
      'شماره چک / پیگیری',
      'روش',
      'توضیحات',
    ];

    pw.Widget cell(String value, {bool header = false}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        alignment: pw.Alignment.centerRight,
        child: pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Text(
            value,
            style: pw.TextStyle(
              font: header ? boldFont : null,
              fontSize: header ? 9 : 8,
            ),
            textAlign: pw.TextAlign.right,
          ),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.0),
        1: pw.FlexColumnWidth(0.8),
        2: pw.FlexColumnWidth(1.25),
        3: pw.FlexColumnWidth(1.25),
        4: pw.FlexColumnWidth(1.0),
        5: pw.FlexColumnWidth(2.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final value in headerValues) cell(value, header: true),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              cell(_formatJalali(row.effectiveDate)),
              cell(row.typeLabel),
              cell(numberFormat.format(row.amountRial)),
              cell(row.reference),
              cell(row.method),
              cell(row.description),
            ],
          ),
      ],
    );
  }

  int _sumByKind(
    Iterable<CompanyAccountActivityRow> rows,
    CompanyAccountActivityKind kind,
  ) {
    return rows
        .where((row) => row.kind == kind)
        .fold<int>(0, (sum, row) => sum + row.amountRial);
  }

  String _formatJalali(DateTime date) {
    final jalali = Jalali.fromDateTime(date.toLocal());

    return '${jalali.year.toString().padLeft(4, '0')}/'
        '${jalali.month.toString().padLeft(2, '0')}/'
        '${jalali.day.toString().padLeft(2, '0')}';
  }

  String _safeName(String value) {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    return sanitized.isEmpty ? 'company' : sanitized;
  }

  String _fileStamp() {
    final now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
