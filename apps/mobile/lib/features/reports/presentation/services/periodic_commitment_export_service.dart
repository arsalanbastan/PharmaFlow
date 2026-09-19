import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show NumberFormat;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../data/models/cheque.dart';
import '../../../cheques/presentation/providers/active_cheques_provider.dart';
import '../../../dashboard/domain/models/commitment_period.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/widgets/dashboard_visuals.dart';

class PeriodicCommitmentReportSection {
  const PeriodicCommitmentReportSection({
    required this.period,
    required this.cheques,
    required this.totalAmount,
  });

  final CommitmentPeriod period;
  final List<Cheque> cheques;
  final int totalAmount;

  int get chequeCount => cheques.length;
}

class PeriodicCommitmentExportService {
  const PeriodicCommitmentExportService();

  List<PeriodicCommitmentReportSection> buildSections({
    required List<CommitmentPeriod> periods,
    required ActiveChequeLookupData lookup,
    DateTime? fromDate,
    DateTime? toDate,
  }) {
    final eligible = commitmentEligibleCheques(lookup.cheques);

    final normalizedFrom = fromDate == null ? null : _dateOnly(fromDate);
    final normalizedToExclusive = toDate == null
        ? null
        : _dateOnly(toDate).add(const Duration(days: 1));

    final sections = <PeriodicCommitmentReportSection>[];

    for (final period in periods) {
      final cheques =
          eligible
              .where((cheque) {
                if (cheque.dueDate.isBefore(period.startDate) ||
                    !cheque.dueDate.isBefore(period.endDate)) {
                  return false;
                }

                if (normalizedFrom != null &&
                    cheque.dueDate.isBefore(normalizedFrom)) {
                  return false;
                }

                if (normalizedToExclusive != null &&
                    !cheque.dueDate.isBefore(normalizedToExclusive)) {
                  return false;
                }

                return true;
              })
              .toList(growable: false)
            ..sort((a, b) {
              final dueCompare = a.dueDate.compareTo(b.dueDate);

              if (dueCompare != 0) {
                return dueCompare;
              }

              final companyA = lookup.companyNames[a.companyId] ?? '';
              final companyB = lookup.companyNames[b.companyId] ?? '';

              final companyCompare = companyA.compareTo(companyB);

              if (companyCompare != 0) {
                return companyCompare;
              }

              return a.chequeNumber.compareTo(b.chequeNumber);
            });

      if (cheques.isEmpty) {
        continue;
      }

      final totalAmount = cheques.fold<int>(
        0,
        (sum, cheque) => sum + cheque.amountRial,
      );

      sections.add(
        PeriodicCommitmentReportSection(
          period: period,
          cheques: List<Cheque>.unmodifiable(cheques),
          totalAmount: totalAmount,
        ),
      );
    }

    return List<PeriodicCommitmentReportSection>.unmodifiable(sections);
  }

  Future<void> shareExcel({
    required List<PeriodicCommitmentReportSection> sections,
    required ActiveChequeLookupData lookup,
    required DashboardAmountThresholds thresholds,
    required DateTime reportDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (sections.isEmpty) {
      throw StateError('تعهدی برای خروجی وجود ندارد.');
    }

    final excel = Excel.createExcel();

    final sheetName = excel.getDefaultSheet() ?? 'Sheet1';
    final sheet = excel[sheetName];

    sheet.isRTL = true;

    var rowIndex = 0;

    final titleStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final metaStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#334155'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    final tableHeaderStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    final dataStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
    );

    _writeExcelRow(sheet, rowIndex++, <CellValue?>[
      TextCellValue('گزارش دوره‌ای تعهدات'),
    ], style: titleStyle);

    _writeExcelRow(sheet, rowIndex++, <CellValue?>[
      TextCellValue('تاریخ گزارش: ${formatJalaliDate(reportDate)}'),
    ], style: metaStyle);

    _writeExcelRow(sheet, rowIndex++, <CellValue?>[
      TextCellValue('بازه گزارش: ${formatRangeLabel(fromDate, toDate)}'),
    ], style: metaStyle);

    final allChequeCount = sections.fold<int>(
      0,
      (sum, section) => sum + section.chequeCount,
    );

    final grandTotal = sections.fold<int>(
      0,
      (sum, section) => sum + section.totalAmount,
    );

    _writeExcelRow(sheet, rowIndex++, <CellValue?>[
      TextCellValue('تعداد کل چک‌ها'),
      IntCellValue(allChequeCount),
      TextCellValue('جمع کل تعهدات (ریال)'),
      IntCellValue(grandTotal),
    ], style: metaStyle);

    rowIndex += 1;

    for (final section in sections) {
      final tone = dashboardAmountTone(
        section.totalAmount,
        thresholds: thresholds,
      );

      final sectionStyle = CellStyle(
        bold: true,
        fontColorHex: _excelAccentColor(tone),
        backgroundColorHex: _excelSoftColor(tone),
        horizontalAlign: HorizontalAlign.Right,
        verticalAlign: VerticalAlign.Center,
        textWrapping: TextWrapping.WrapText,
      );

      _writeExcelRow(sheet, rowIndex++, <CellValue?>[
        TextCellValue(section.period.title),
        TextCellValue('تعداد چک'),
        IntCellValue(section.chequeCount),
        TextCellValue('جمع دوره (ریال)'),
        IntCellValue(section.totalAmount),
        null,
        null,
      ], style: sectionStyle);

      _writeExcelRow(sheet, rowIndex++, <CellValue?>[
        TextCellValue('دوره'),
        TextCellValue('تاریخ سررسید'),
        TextCellValue('نام شرکت'),
        TextCellValue('شماره چک'),
        TextCellValue('بانک / حساب'),
        TextCellValue('مبلغ (ریال)'),
        TextCellValue('وضعیت صیاد'),
      ], style: tableHeaderStyle);

      for (final cheque in section.cheques) {
        final bank = lookup.bankAccountsById[cheque.bankAccountId];

        final bankText = bank == null
            ? (lookup.bankAccountNames[cheque.bankAccountId] ?? '—')
            : '${bank.bankName} - ${bank.accountTitle}';

        _writeExcelRow(sheet, rowIndex++, <CellValue?>[
          TextCellValue(section.period.title),
          TextCellValue(formatJalaliDate(cheque.dueDate)),
          TextCellValue(lookup.companyNames[cheque.companyId] ?? '—'),
          TextCellValue(cheque.chequeNumber),
          TextCellValue(bankText),
          IntCellValue(cheque.amountRial),
          TextCellValue(cheque.isRegisteredInSayad ? 'ثبت شده' : 'ثبت نشده'),
        ], style: dataStyle);
      }

      rowIndex += 1;
    }

    final totalStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0F172A'),
      backgroundColorHex: ExcelColor.fromHexString('#F1F5F9'),
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
    );

    _writeExcelRow(sheet, rowIndex, <CellValue?>[
      TextCellValue('جمع کل گزارش'),
      TextCellValue('تعداد چک'),
      IntCellValue(allChequeCount),
      TextCellValue('جمع مبلغ (ریال)'),
      IntCellValue(grandTotal),
    ], style: totalStyle);

    sheet.setColumnWidth(0, 19);
    sheet.setColumnWidth(1, 16);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 20);
    sheet.setColumnWidth(4, 32);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 16);

    final bytes = excel.encode();

    if (bytes == null) {
      throw StateError('ساخت فایل Excel ناموفق بود.');
    }

    final file = await _writeTemporaryFile(
      fileName: 'pharmaflow_periodic_commitments_${_fileStamp()}.xlsx',
      bytes: bytes,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        title: 'گزارش دوره‌ای تعهدات',
        subject: 'گزارش دوره‌ای تعهدات PharmaFlow',
      ),
    );
  }

  Future<void> sharePdf({
    required List<PeriodicCommitmentReportSection> sections,
    required ActiveChequeLookupData lookup,
    required DashboardAmountThresholds thresholds,
    required DateTime reportDate,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    if (sections.isEmpty) {
      throw StateError('تعهدی برای خروجی وجود ندارد.');
    }

    final regularData = await rootBundle.load(
      'assets/fonts/Vazirmatn-Regular.ttf',
    );

    final boldData = await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');

    final regularFont = pw.Font.ttf(regularData);
    final boldFont = pw.Font.ttf(boldData);

    final numberFormat = NumberFormat.decimalPattern('en');

    final allChequeCount = sections.fold<int>(
      0,
      (sum, section) => sum + section.chequeCount,
    );

    final grandTotal = sections.fold<int>(
      0,
      (sum, section) => sum + section.totalAmount,
    );

    final pdf = pw.Document(
      title: 'گزارش دوره‌ای تعهدات',
      author: 'PharmaFlow',
      theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(24),
        maxPages: 200,
        footer: (context) {
          return pw.Align(
            alignment: pw.Alignment.center,
            child: pw.Text(
              'صفحه ${context.pageNumber} از ${context.pagesCount}',
              style: pw.TextStyle(
                font: regularFont,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
          );
        },
        build: (context) {
          final widgets = <pw.Widget>[
            pw.Text(
              'گزارش دوره‌ای تعهدات',
              style: pw.TextStyle(font: boldFont, fontSize: 18),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'تاریخ گزارش: ${formatJalaliDate(reportDate)}',
              style: pw.TextStyle(font: regularFont, fontSize: 10),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'بازه گزارش: ${formatRangeLabel(fromDate, toDate)}',
              style: pw.TextStyle(font: regularFont, fontSize: 10),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              'تعداد کل چک‌ها: $allChequeCount    '
              'جمع کل تعهدات: ${numberFormat.format(grandTotal)} ریال',
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
            pw.SizedBox(height: 14),
          ];

          for (final section in sections) {
            final tone = dashboardAmountTone(
              section.totalAmount,
              thresholds: thresholds,
            );

            final accent = _pdfAccentColor(tone);
            final soft = _pdfSoftColor(tone);

            widgets.add(
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: pw.BoxDecoration(
                  color: soft,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: accent, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      section.period.title,
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 11,
                        color: accent,
                      ),
                    ),
                    pw.Text(
                      'تعداد چک: ${section.chequeCount}    '
                      'جمع دوره: '
                      '${numberFormat.format(section.totalAmount)} ریال',
                      style: pw.TextStyle(
                        font: boldFont,
                        fontSize: 9,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ),
            );

            widgets.add(pw.SizedBox(height: 5));

            final tableData = <List<dynamic>>[
              <dynamic>[
                'تاریخ سررسید',
                'نام شرکت',
                'شماره چک',
                'بانک / حساب',
                'مبلغ (ریال)',
                'وضعیت صیاد',
              ],
              ...section.cheques.map((cheque) {
                final bank = lookup.bankAccountsById[cheque.bankAccountId];

                final bankText = bank == null
                    ? (lookup.bankAccountNames[cheque.bankAccountId] ?? '—')
                    : '${bank.bankName} - ${bank.accountTitle}';

                return <dynamic>[
                  formatJalaliDate(cheque.dueDate),
                  lookup.companyNames[cheque.companyId] ?? '—',
                  cheque.chequeNumber,
                  bankText,
                  numberFormat.format(cheque.amountRial),
                  cheque.isRegisteredInSayad ? 'ثبت شده' : 'ثبت نشده',
                ];
              }),
            ];

            widgets.add(
              pw.TableHelper.fromTextArray(
                data: tableData,
                headerCount: 1,
                tableDirection: pw.TextDirection.rtl,
                headerDirection: pw.TextDirection.rtl,
                headerAlignment: pw.Alignment.center,
                cellAlignment: pw.Alignment.centerRight,
                headerStyle: pw.TextStyle(font: boldFont, fontSize: 8),
                cellStyle: pw.TextStyle(font: regularFont, fontSize: 7.5),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
                cellPadding: const pw.EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 5,
                ),
                columnWidths: const <int, pw.TableColumnWidth>{
                  0: pw.FlexColumnWidth(1.15),
                  1: pw.FlexColumnWidth(1.75),
                  2: pw.FlexColumnWidth(1.25),
                  3: pw.FlexColumnWidth(1.9),
                  4: pw.FlexColumnWidth(1.35),
                  5: pw.FlexColumnWidth(1.05),
                },
              ),
            );

            widgets.add(pw.SizedBox(height: 12));
          }

          widgets.add(
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey200,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                'جمع کل گزارش: '
                '$allChequeCount چک | '
                '${numberFormat.format(grandTotal)} ریال',
                style: pw.TextStyle(font: boldFont, fontSize: 10),
              ),
            ),
          );

          return widgets;
        },
      ),
    );

    final bytes = await pdf.save();

    final file = await _writeTemporaryFile(
      fileName: 'pharmaflow_periodic_commitments_${_fileStamp()}.pdf',
      bytes: bytes,
    );

    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[XFile(file.path)],
        title: 'گزارش دوره‌ای تعهدات',
        subject: 'گزارش دوره‌ای تعهدات PharmaFlow',
      ),
    );
  }

  String formatRangeLabel(DateTime? fromDate, DateTime? toDate) {
    if (fromDate == null && toDate == null) {
      return 'همه تعهدات';
    }

    if (fromDate != null && toDate == null) {
      return 'از ${formatJalaliDate(fromDate)} به بعد';
    }

    if (fromDate == null && toDate != null) {
      return 'تا ${formatJalaliDate(toDate)}';
    }

    return 'از ${formatJalaliDate(fromDate!)} '
        'تا ${formatJalaliDate(toDate!)}';
  }

  String formatJalaliDate(DateTime value) {
    final date = Jalali.fromDateTime(value);

    final text =
        '${date.year.toString().padLeft(4, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.day.toString().padLeft(2, '0')}';

    return _toPersianDigits(text);
  }

  void _writeExcelRow(
    Sheet sheet,
    int rowIndex,
    List<CellValue?> values, {
    CellStyle? style,
  }) {
    for (var columnIndex = 0; columnIndex < values.length; columnIndex++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(
          columnIndex: columnIndex,
          rowIndex: rowIndex,
        ),
        values[columnIndex],
        cellStyle: style,
      );
    }
  }

  ExcelColor _excelAccentColor(DashboardAmountTone tone) {
    return switch (tone) {
      DashboardAmountTone.green => ExcelColor.fromHexString('#1B8A4B'),
      DashboardAmountTone.orange => ExcelColor.fromHexString('#C77710'),
      DashboardAmountTone.red => ExcelColor.fromHexString('#B42318'),
    };
  }

  ExcelColor _excelSoftColor(DashboardAmountTone tone) {
    return switch (tone) {
      DashboardAmountTone.green => ExcelColor.fromHexString('#EAF7EE'),
      DashboardAmountTone.orange => ExcelColor.fromHexString('#FFF0DB'),
      DashboardAmountTone.red => ExcelColor.fromHexString('#FFE8E6'),
    };
  }

  PdfColor _pdfAccentColor(DashboardAmountTone tone) {
    return switch (tone) {
      DashboardAmountTone.green => const PdfColor(0.106, 0.541, 0.294),
      DashboardAmountTone.orange => const PdfColor(0.780, 0.467, 0.063),
      DashboardAmountTone.red => const PdfColor(0.706, 0.137, 0.094),
    };
  }

  PdfColor _pdfSoftColor(DashboardAmountTone tone) {
    return switch (tone) {
      DashboardAmountTone.green => const PdfColor(0.918, 0.969, 0.933),
      DashboardAmountTone.orange => const PdfColor(1.0, 0.941, 0.859),
      DashboardAmountTone.red => const PdfColor(1.0, 0.910, 0.902),
    };
  }

  Future<File> _writeTemporaryFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final directory = await getTemporaryDirectory();

    final file = File(p.join(directory.path, fileName));

    await file.writeAsBytes(bytes, flush: true);

    return file;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  String _toPersianDigits(String value) {
    const english = <String>['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];

    const persian = <String>['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    var result = value;

    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }

    return result;
  }

  String _fileStamp() {
    final now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}'
        '${two(now.month)}'
        '${two(now.day)}_'
        '${two(now.hour)}'
        '${two(now.minute)}'
        '${two(now.second)}';
  }
}
