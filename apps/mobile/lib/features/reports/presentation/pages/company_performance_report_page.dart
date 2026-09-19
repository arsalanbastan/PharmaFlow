import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../providers/reports_providers.dart';
import 'report_cheques_page.dart';

class CompanyPerformanceReportPage extends ConsumerStatefulWidget {
  const CompanyPerformanceReportPage({super.key});

  @override
  ConsumerState<CompanyPerformanceReportPage> createState() =>
      _CompanyPerformanceReportPageState();
}

class _CompanyPerformanceReportPageState
    extends ConsumerState<CompanyPerformanceReportPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(companyPerformanceReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش عملکرد شرکت‌ها')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(companyPerformanceReportProvider);
            await ref.read(companyPerformanceReportProvider.future);
          },
          child: rowsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('بارگذاری گزارش با خطا مواجه شد.')),
              ],
            ),
            data: (rows) {
              final search = _searchController.text.trim().toLowerCase();
              final filtered = rows
                  .where(
                    (row) =>
                        search.isEmpty ||
                        row.companyName.toLowerCase().contains(search),
                  )
                  .toList(growable: false);

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                itemCount: filtered.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          hintText: 'جستجو بر اساس نام شرکت...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    );
                  }

                  final row = filtered[index - 1];
                  final totalText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.totalAmount);
                  final avgText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.averageAmount.round());

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReportChequesPage(
                              title: 'چک‌های ${row.companyName}',
                              filter: ReportChequeFilter(
                                companyId: row.companyId,
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              row.companyName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _metricChip('تعداد چک', '${row.chequeCount}'),
                                _metricChip('جمع مبلغ', '$totalText ریال'),
                                _metricChip(
                                  'ثبت در صیاد',
                                  '${row.registeredInSayadCount}',
                                ),
                                _metricChip(
                                  'ثبت نشده',
                                  '${row.notRegisteredInSayadCount}',
                                ),
                                _metricChip('لغوشده', '${row.cancelledCount}'),
                                _metricChip('وصول‌شده', '${row.paidCount}'),
                                _metricChip('میانگین مبلغ', '$avgText ریال'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'نزدیک‌ترین سررسید: ${_jalaliText(row.nearestDueDate)}',
                            ),
                            Text(
                              'آخرین تاریخ چک: ${_jalaliText(row.latestChequeDate)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _metricChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$title: $value'),
    );
  }

  String _jalaliText(DateTime? value) {
    if (value == null) {
      return '—';
    }

    final date = Jalali.fromDateTime(value);
    final formatted =
        '${date.year.toString().padLeft(4, '0')}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return _toPersianDigits(formatted);
  }

  String _toPersianDigits(String value) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    var result = value;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], persian[i]);
    }

    return result;
  }
}
