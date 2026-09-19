import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../../cheques/presentation/providers/active_cheques_provider.dart';
import '../../../dashboard/domain/models/dashboard_summary.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../dashboard/presentation/widgets/dashboard_visuals.dart';
import '../../../dashboard/presentation/widgets/jalali_commitment_calendar_view.dart';
import '../../../settings/presentation/providers/app_preferences_provider.dart';
import '../providers/reports_providers.dart';
import '../services/periodic_commitment_export_service.dart';
import 'report_cheques_page.dart';

class PeriodicCommitmentsReportPage extends ConsumerStatefulWidget {
  const PeriodicCommitmentsReportPage({super.key});

  @override
  ConsumerState<PeriodicCommitmentsReportPage> createState() =>
      _PeriodicCommitmentsReportPageState();
}

class _PeriodicCommitmentsReportPageState
    extends ConsumerState<PeriodicCommitmentsReportPage> {
  static const _exportService = PeriodicCommitmentExportService();

  static final DateTime _pickerFirstDate = DateTime(2020, 1, 1);

  static final DateTime _pickerLastDate = DateTime(2035, 12, 31);

  DateTime? _fromDate;
  DateTime? _toDate;

  bool _exportingExcel = false;
  bool _exportingPdf = false;

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);

    final lookupAsync = ref.watch(activeChequeLookupProvider);

    final settings = ref.watch(appPreferencesProvider).valueOrNull;

    final thresholds = DashboardAmountThresholds(
      green:
          settings?.thresholds.green ?? defaultDashboardAmountThresholds.green,
      orange:
          settings?.thresholds.orange ??
          defaultDashboardAmountThresholds.orange,
      red: settings?.thresholds.red ?? defaultDashboardAmountThresholds.red,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش دوره‌ای تعهدات')),
        body: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              _errorList('بارگذاری دوره‌های تعهدات با خطا مواجه شد.'),
          data: (summary) {
            return lookupAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  _errorList('بارگذاری جزئیات چک‌ها با خطا مواجه شد.'),
              data: (lookup) {
                return _buildReport(
                  summary: summary,
                  lookup: lookup,
                  thresholds: thresholds,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildReport({
    required DashboardSummary summary,
    required ActiveChequeLookupData lookup,
    required DashboardAmountThresholds thresholds,
  }) {
    final sections = _exportService.buildSections(
      periods: summary.periods,
      lookup: lookup,
      fromDate: _fromDate,
      toDate: _toDate,
    );

    final totalAmount = sections.fold<int>(
      0,
      (sum, section) => sum + section.totalAmount,
    );

    final chequeCount = sections.fold<int>(
      0,
      (sum, section) => sum + section.chequeCount,
    );

    final amountText = NumberFormat.decimalPattern('en').format(totalAmount);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(activeChequeLookupProvider);
        ref.invalidate(dashboardSummaryProvider);

        await Future.wait([
          ref.read(activeChequeLookupProvider.future),
          ref.read(dashboardSummaryProvider.future),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
        children: [
          _buildFilterCard(),
          const SizedBox(height: 10),

          Card(
            elevation: 0.3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'خلاصه گزارش',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تاریخ گزارش: '
                    '${_exportService.formatJalaliDate(DateTime.now())}',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'بازه گزارش: '
                    '${_exportService.formatRangeLabel(_fromDate, _toDate)}',
                  ),
                  const SizedBox(height: 4),
                  Text('تعداد چک: $chequeCount'),
                  const SizedBox(height: 4),
                  Text(
                    'جمع تعهدات: $amountText ریال',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      sections.isEmpty || _exportingExcel || _exportingPdf
                      ? null
                      : () => _shareExcel(
                          sections: sections,
                          lookup: lookup,
                          thresholds: thresholds,
                        ),
                  icon: _exportingExcel
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.table_view_outlined),
                  label: const Text('خروجی Excel'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      sections.isEmpty || _exportingExcel || _exportingPdf
                      ? null
                      : () => _sharePdf(
                          sections: sections,
                          lookup: lookup,
                          thresholds: thresholds,
                        ),
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('خروجی PDF'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (sections.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text(
                  'در بازه انتخاب‌شده تعهدی وجود ندارد.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            for (final section in sections) ...[
              _buildPeriodCard(section: section, thresholds: thresholds),
              const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    final hasFilter = _fromDate != null || _toDate != null;

    return Card(
      elevation: 0.3,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.filter_alt_outlined, size: 20),
                SizedBox(width: 8),
                Text(
                  'فیلتر تاریخ سررسید',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'اگر تاریخی انتخاب نشود، همه تعهدات گزارش می‌شوند.',
              style: TextStyle(
                fontSize: 12.5,
                color: DashboardThemeColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickFromDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      _fromDate == null
                          ? 'از تاریخ'
                          : _exportService.formatJalaliDate(_fromDate!),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickToDate,
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _toDate == null
                          ? 'تا تاریخ'
                          : _exportService.formatJalaliDate(_toDate!),
                    ),
                  ),
                ),
              ],
            ),
            if (hasFilter) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                    });
                  },
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('پاک کردن فیلتر'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodCard({
    required PeriodicCommitmentReportSection section,
    required DashboardAmountThresholds thresholds,
  }) {
    final accent = dashboardAmountColor(
      section.totalAmount,
      thresholds: thresholds,
    );

    final surface = dashboardSoftAmountColor(
      section.totalAmount,
      thresholds: thresholds,
    );

    final border = dashboardSoftAmountBorderColor(
      section.totalAmount,
      thresholds: thresholds,
    );

    final amountText = NumberFormat.decimalPattern(
      'en',
    ).format(section.totalAmount);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: ListTile(
        title: Text(
          section.period.title,
          style: TextStyle(fontWeight: FontWeight.w800, color: accent),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            'تعداد چک: ${section.chequeCount}\n'
            'جمع مبلغ: $amountText ریال',
          ),
        ),
        trailing: Icon(Icons.chevron_left, color: accent),
        onTap: () {
          final from = _maxDate(section.period.startDate, _fromDate);

          final toExclusive = _minDate(
            section.period.endDate,
            _toDate == null
                ? null
                : _dateOnly(_toDate!).add(const Duration(days: 1)),
          );

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ReportChequesPage(
                title: section.period.title,
                filter: ReportChequeFilter(
                  fromDueDate: from,
                  toDueDate: toExclusive,
                  commitmentOnly: true,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickFromDate() async {
    final first = _pickerFirstDate;

    final last = _toDate == null ? _pickerLastDate : _dateOnly(_toDate!);

    final preferred = _fromDate ?? _toDate ?? DateTime.now();

    final initial = _clampDate(preferred, first, last);

    final selected = await _showDashboardCalendarPicker(
      title: 'انتخاب تاریخ شروع',
      confirmSelectionText: 'انتخاب تاریخ شروع',
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = _dateOnly(selected);
    });
  }

  Future<void> _pickToDate() async {
    final first = _fromDate == null ? _pickerFirstDate : _dateOnly(_fromDate!);

    final last = _pickerLastDate;

    final preferred = _toDate ?? _fromDate ?? DateTime.now();

    final initial = _clampDate(preferred, first, last);

    final selected = await _showDashboardCalendarPicker(
      title: 'انتخاب تاریخ پایان',
      confirmSelectionText: 'انتخاب تاریخ پایان',
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = _dateOnly(selected);
    });
  }

  Future<DateTime?> _showDashboardCalendarPicker({
    required String title,
    required String confirmSelectionText,
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) {
    return showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height * 0.90;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: SizedBox(
              height: height,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'بستن',
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                          },
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: JalaliCommitmentCalendarView(
                      initialSelectedDate: initialDate,
                      firstDate: firstDate,
                      lastDate: lastDate,
                      requireExplicitSelection: true,
                      confirmSelectionText: confirmSelectionText,
                      onDateSelected: (date) {
                        Navigator.of(sheetContext).pop(_dateOnly(date));
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareExcel({
    required List<PeriodicCommitmentReportSection> sections,
    required ActiveChequeLookupData lookup,
    required DashboardAmountThresholds thresholds,
  }) async {
    setState(() {
      _exportingExcel = true;
    });

    try {
      await _exportService.shareExcel(
        sections: sections,
        lookup: lookup,
        thresholds: thresholds,
        reportDate: DateTime.now(),
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (error) {
      if (mounted) {
        _showMessage('ساخت فایل Excel ناموفق بود: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingExcel = false;
        });
      }
    }
  }

  Future<void> _sharePdf({
    required List<PeriodicCommitmentReportSection> sections,
    required ActiveChequeLookupData lookup,
    required DashboardAmountThresholds thresholds,
  }) async {
    setState(() {
      _exportingPdf = true;
    });

    try {
      await _exportService.sharePdf(
        sections: sections,
        lookup: lookup,
        thresholds: thresholds,
        reportDate: DateTime.now(),
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (error) {
      if (mounted) {
        _showMessage('ساخت فایل PDF ناموفق بود: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _exportingPdf = false;
        });
      }
    }
  }

  Widget _errorList(String text) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(child: Text(text)),
      ],
    );
  }

  DateTime _clampDate(DateTime value, DateTime first, DateTime last) {
    final normalized = _dateOnly(value);

    if (normalized.isBefore(first)) {
      return _dateOnly(first);
    }

    if (normalized.isAfter(last)) {
      return _dateOnly(last);
    }

    return normalized;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _maxDate(DateTime first, DateTime? second) {
    if (second == null) {
      return first;
    }

    return first.isAfter(second) ? first : second;
  }

  DateTime _minDate(DateTime first, DateTime? second) {
    if (second == null) {
      return first;
    }

    return first.isBefore(second) ? first : second;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
