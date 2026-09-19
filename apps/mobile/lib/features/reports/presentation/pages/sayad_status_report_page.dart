import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reports_providers.dart';
import 'report_cheques_page.dart';

class SayadStatusReportPage extends ConsumerWidget {
  const SayadStatusReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(sayadStatusReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش وضعیت صیاد')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sayadStatusReportProvider);
            await ref.read(sayadStatusReportProvider.future);
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
                  Card(
                    child: ListTile(
                      title: const Text('چک‌های ثبت شده در صیاد'),
                      subtitle: Text('${summary.registeredCount} چک'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReportChequesPage(
                              title: 'چک‌های ثبت شده در صیاد',
                              filter: ReportChequeFilter(
                                isRegisteredInSayad: true,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('چک‌های ثبت نشده در صیاد'),
                      subtitle: Text('${summary.notRegisteredCount} چک'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReportChequesPage(
                              title: 'چک‌های ثبت نشده در صیاد',
                              filter: ReportChequeFilter(
                                isRegisteredInSayad: false,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('درصد ثبت در صیاد'),
                      subtitle: Text(
                        '${summary.registrationPercentage.toStringAsFixed(1)}%',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'شرکت‌های دارای بیشترین چک ثبت‌نشده',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ...summary.topUnregisteredCompanies.map(
                    (row) => Card(
                      child: ListTile(
                        title: Text(row.companyName),
                        subtitle: Text('${row.count} چک ثبت نشده'),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportChequesPage(
                                title: 'چک‌های ثبت نشده ${row.companyName}',
                                filter: ReportChequeFilter(
                                  companyId: row.companyId,
                                  isRegisteredInSayad: false,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
