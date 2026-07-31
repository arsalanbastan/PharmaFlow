import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:material_drum_picker/material_drum_picker.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/dashboard_visuals.dart';
import '../../domain/models/commitment_company_summary.dart';
import '../../domain/models/commitment_day_summary.dart';

class JalaliCommitmentCalendarPage extends ConsumerStatefulWidget {
  const JalaliCommitmentCalendarPage({super.key});

  @override
  ConsumerState<JalaliCommitmentCalendarPage> createState() =>
      _JalaliCommitmentCalendarPageState();
}

class _JalaliCommitmentCalendarPageState
    extends ConsumerState<JalaliCommitmentCalendarPage> {
  static final DateTime _calendarFirstDate = DateTime(2020, 1, 1);
  static final DateTime _calendarLastDate = DateTime(2035, 12, 31);

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDate = _dateOnly(today);
  }

  @override
  Widget build(BuildContext context) {
    final allDaysRange = CommitmentPeriodRange(
      startDate: _calendarFirstDate,
      endDate: _calendarLastDate.add(const Duration(days: 1)),
    );

    final monthDaysAsync = ref.watch(
      commitmentDaysByPeriodProvider(allDaysRange),
    );
    final monthDays =
        monthDaysAsync.valueOrNull ?? const <CommitmentDaySummary>[];
    final daysByDate = <DateTime, CommitmentDaySummary>{
      for (final day in monthDays) _dateOnly(day.date): day,
    };

    final selectedDayStart = _dateOnly(_selectedDate);
    final selectedDayEnd = selectedDayStart.add(const Duration(days: 1));
    final selectedCompaniesAsync = ref.watch(
      commitmentCompaniesByDayProvider(
        CommitmentDayRange(dayStart: selectedDayStart, dayEnd: selectedDayEnd),
      ),
    );

    final jalaliDate = Jalali.fromDateTime(_selectedDate);
    final selectedSummary = daysByDate[selectedDayStart];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تقویم تعهدات')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              _IntroCard(monthDaysAsync: monthDaysAsync),
              const SizedBox(height: 12),
              Card(
                elevation: 0.3,
                shadowColor: DashboardThemeColors.shadow,
                surfaceTintColor: Colors.transparent,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(
                    color: DashboardThemeColors.border,
                    width: 0.8,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            size: 19,
                            color: DashboardThemeColors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تقویم ماه جاری',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: DashboardThemeColors.ink,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DrumPicker(
                        initialDate: _selectedDate,
                        currentDate: DateTime.now(),
                        firstDate: _calendarFirstDate,
                        lastDate: _calendarLastDate,
                        initialMode: DrumPickerMode.calendar,
                        showModeToggle: false,
                        showHeader: false,
                        showQuickSelects: false,
                        showActions: false,
                        calendar: DrumCalendarType.jalali,
                        textDirection: TextDirection.rtl,
                        onChanged: (date) {
                          setState(() {
                            _selectedDate = _dateOnly(date);
                          });
                        },
                        eventLoader: (day) {
                          final summary = daysByDate[_dateOnly(day)];
                          if (summary == null || summary.commitmentCount == 0) {
                            return const <DrumEventMarker>[];
                          }

                          final markerColor = dashboardAmountColor(
                            summary.totalAmount,
                          );
                          return List<DrumEventMarker>.generate(
                            summary.commitmentCount,
                            (_) => DrumEventMarker(color: markerColor),
                          );
                        },
                        locale: const Locale('fa'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _SelectedDayCard(
                selectedDate: _selectedDate,
                jalaliDate: jalaliDate,
                summary: selectedSummary,
                companiesAsync: selectedCompaniesAsync,
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.monthDaysAsync});

  final AsyncValue<List<CommitmentDaySummary>> monthDaysAsync;

  @override
  Widget build(BuildContext context) {
    final dayCount = monthDaysAsync.valueOrNull?.length ?? 0;

    return Card(
      elevation: 0.3,
      shadowColor: DashboardThemeColors.shadow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: DashboardThemeColors.border, width: 0.8),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [DashboardThemeColors.greenSoft, Colors.white],
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DashboardThemeColors.headerHighlight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_available_outlined,
                color: DashboardThemeColors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'نمای ماهانه تعهدها',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: DashboardThemeColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayCount == 0
                        ? 'برای ماه نمایش‌داده‌شده تعهدی ثبت نشده است'
                        : 'روزهای دارای تعهد با نقطه‌های رنگی مشخص شده‌اند',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: DashboardThemeColors.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.selectedDate,
    required this.jalaliDate,
    required this.summary,
    required this.companiesAsync,
  });

  final DateTime selectedDate;
  final Jalali jalaliDate;
  final CommitmentDaySummary? summary;
  final AsyncValue<List<CommitmentCompanySummary>> companiesAsync;

  @override
  Widget build(BuildContext context) {
    final amount = summary?.totalAmount ?? 0;
    final toneColor = dashboardAmountColor(amount);
    final surfaceColor = dashboardSoftAmountColor(amount);
    final amountText = NumberFormat.decimalPattern('en').format(amount);
    final jalaliLabel =
        '${jalaliDate.day} ${_jalaliMonthNames[jalaliDate.month - 1]} ${jalaliDate.year}';
    final gregorianLabel =
        '${selectedDate.year}/${selectedDate.month}/${selectedDate.day}';

    return Card(
      elevation: 0.3,
      shadowColor: DashboardThemeColors.shadow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: DashboardThemeColors.border, width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.event_note_outlined, color: toneColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'جزئیات روز انتخاب‌شده',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DashboardThemeColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$gregorianLabel  |  $jalaliLabel',
                        style: const TextStyle(
                          fontSize: 12.2,
                          color: DashboardThemeColors.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: surfaceColor.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: surfaceColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      title: 'تعداد تعهد',
                      value: '${summary?.commitmentCount ?? 0}',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricTile(
                      title: 'جمع مبلغ',
                      value: '$amountText ریال',
                      valueColor: toneColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            companiesAsync.when(
              data: (companies) {
                if (companies.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'برای این روز تعهدی ثبت نشده است.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: DashboardThemeColors.muted,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (var index = 0; index < companies.length; index++) ...[
                      _CompanyTile(company: companies[index]),
                      if (index < companies.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (error, stack) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'خطا در بارگذاری جزئیات روز',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: DashboardThemeColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.title,
    required this.value,
    this.valueColor = DashboardThemeColors.ink,
  });

  final String title;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardThemeColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              color: DashboardThemeColors.muted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({required this.company});

  final CommitmentCompanySummary company;

  @override
  Widget build(BuildContext context) {
    final amountText = NumberFormat.decimalPattern(
      'en',
    ).format(company.totalAmount);
    final accent = dashboardAmountColor(company.totalAmount);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashboardThemeColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.companyName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: DashboardThemeColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${company.chequeCount} چک  |  $amountText ریال',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: DashboardThemeColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _jalaliMonthNames = <String>[
  'فروردین',
  'اردیبهشت',
  'خرداد',
  'تیر',
  'مرداد',
  'شهریور',
  'مهر',
  'آبان',
  'آذر',
  'دی',
  'بهمن',
  'اسفند',
];
