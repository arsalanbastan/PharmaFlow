import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../providers/reports_providers.dart';
import 'report_cheques_page.dart';

class UpcomingCommitmentsReportPage extends ConsumerWidget {
  const UpcomingCommitmentsReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(upcomingCommitmentsReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش تعهدات پیش رو')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(upcomingCommitmentsReportProvider);
            await ref.read(upcomingCommitmentsReportProvider.future);
          },
          child: bucketsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('بارگذاری گزارش با خطا مواجه شد.')),
              ],
            ),
            data: (buckets) {
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                itemCount: buckets.length,
                itemBuilder: (context, index) {
                  final bucket = buckets[index];
                  final totalText = NumberFormat.decimalPattern(
                    'en',
                  ).format(bucket.totalAmount);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(bucket.title),
                      subtitle: Text(
                        'تعداد چک: ${bucket.chequeCount}\n'
                        'جمع مبلغ: $totalText ریال',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: bucket.chequeCount == 0
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ReportChequesPage(
                                    title: 'چک‌های ${bucket.title}',
                                    filter: ReportChequeFilter(
                                      fromDueDate: bucket.start,
                                      toDueDate: bucket.end,
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
