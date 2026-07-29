import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_provider.dart';

class DashboardTestPage extends ConsumerWidget {
  const DashboardTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(
      dashboardSummaryProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Test'),
      ),
      body: dashboardAsync.when(
        data: (summary) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'تعهدات فردا',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                if (!summary.tomorrow.hasCommitment)
                  const Text(
                    'در روز آتی تعهد مالی ثبت نشده است',
                  )
                else
                  ...summary.tomorrow.bankCommitments.map(
                    (item) {
                      return Card(
                        child: ListTile(
                          title: Text(
                            item.bankName,
                          ),
                          trailing: Text(
                            '${item.amount} ریال',
                          ),
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                Text(
                  'تعداد دوره‌ها: ${summary.periods.length}',
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stack) {
          return Center(
            child: Text(
              error.toString(),
            ),
          );
        },
      ),
    );
  }
}