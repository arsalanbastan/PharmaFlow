import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reports_providers.dart';

class ActivityReportPage extends ConsumerWidget {
  const ActivityReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(activityReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش فعالیت روزانه')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activityReportProvider);
            await ref.read(activityReportProvider.future);
          },
          child: summaryAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('بارگذاری گزارش با خطا مواجه شد.')),
              ],
            ),
            data: (summary) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  _metricCard('چک‌های ایجاد شده امروز', summary.createdToday),
                  _metricCard(
                    'چک‌های به‌روزرسانی شده امروز',
                    summary.updatedToday,
                  ),
                  _metricCard('چک‌های حذف شده امروز', summary.deletedToday),
                  _metricCard('آیتم‌های همگام‌شده امروز', summary.syncedToday),
                  _metricCard(
                    'همگام‌سازی‌های ناموفق',
                    summary.failedSynchronizations,
                    emphasize: summary.failedSynchronizations > 0,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _metricCard(String title, int value, {bool emphasize = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        trailing: Text(
          '$value',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: emphasize ? Colors.red.shade700 : null,
          ),
        ),
      ),
    );
  }
}
