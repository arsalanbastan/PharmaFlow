import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reports_providers.dart';
import 'report_cheques_page.dart';

class LargeAmountReportPage extends ConsumerWidget {
  const LargeAmountReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thresholdAsync = ref.watch(largeAmountThresholdProvider);
    final chequesAsync = ref.watch(largeAmountChequesReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش چک‌های مبالغ بزرگ')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(largeAmountThresholdProvider);
            ref.invalidate(largeAmountChequesReportProvider);
            await ref.read(largeAmountChequesReportProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            children: [
              thresholdAsync.when(
                loading: () => const Card(
                  child: ListTile(title: Text('در حال بارگذاری آستانه...')),
                ),
                error: (_, _) => const Card(
                  child: ListTile(
                    title: Text('خواندن آستانه با خطا مواجه شد.'),
                  ),
                ),
                data: (threshold) => Card(
                  child: ListTile(
                    title: const Text('آستانه فعال'),
                    subtitle: Text('$threshold ریال (از تنظیمات)'),
                    trailing: const Icon(Icons.settings),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              chequesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => const Card(
                  child: ListTile(
                    title: Text('بارگذاری گزارش با خطا مواجه شد.'),
                  ),
                ),
                data: (cheques) {
                  if (cheques.isEmpty) {
                    return const Card(
                      child: ListTile(
                        title: Text('موردی برای نمایش وجود ندارد.'),
                      ),
                    );
                  }

                  return Card(
                    child: ListTile(
                      title: Text('${cheques.length} چک مبالغ بزرگ'),
                      subtitle: const Text('مرتب‌سازی: نزولی بر اساس مبلغ'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => thresholdAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, _) => const SizedBox.shrink(),
                              data: (threshold) => ReportChequesPage(
                                title: 'چک‌های بیش از آستانه',
                                filter: ReportChequeFilter(
                                  minAmountRial: threshold,
                                  sortByAmountDesc: true,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
