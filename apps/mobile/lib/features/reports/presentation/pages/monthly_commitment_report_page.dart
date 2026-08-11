import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../providers/reports_providers.dart';
import 'report_cheques_page.dart';

class MonthlyCommitmentReportPage extends ConsumerWidget {
  const MonthlyCommitmentReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(monthlyCommitmentReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش ماهانه تعهدات')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(monthlyCommitmentReportProvider);
            await ref.read(monthlyCommitmentReportProvider.future);
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
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                itemCount: rows.length,
                itemBuilder: (context, index) {
                  final row = rows[index];
                  final totalText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.totalAmount);
                  final maxText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.maxDailyCommitment);
                  final minText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.minDailyCommitment);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(row.monthTitle),
                      subtitle: Text(
                        'تعداد چک: ${row.chequeCount}\n'
                        'جمع مبلغ: $totalText ریال\n'
                        'بیشینه تعهد روزانه: $maxText ریال\n'
                        'کمینه تعهد روزانه: $minText ریال',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReportChequesPage(
                              title: 'جزئیات ${row.monthTitle}',
                              filter: ReportChequeFilter(
                                jalaliYear: row.jalaliYear,
                                jalaliMonth: row.jalaliMonth,
                                commitmentOnly: true,
                              ),
                            ),
                          ),
                        );
                      },
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
}
