import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../providers/reports_providers.dart';
import 'report_cheques_page.dart';

class BankAccountSummaryReportPage extends ConsumerWidget {
  const BankAccountSummaryReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(bankAccountSummaryReportProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('گزارش حساب‌های بانکی')),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bankAccountSummaryReportProvider);
            await ref.read(bankAccountSummaryReportProvider.future);
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
                  ).format(row.totalIssuedAmount);
                  final upcomingText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.upcomingAmount);
                  final averageText = NumberFormat.decimalPattern(
                    'en',
                  ).format(row.averageAmount.round());

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text('${row.bankName} - ${row.accountTitle}'),
                      subtitle: Text(
                        'تعداد چک: ${row.chequeCount}\n'
                        'جمع مبالغ: $totalText ریال\n'
                        'مبلغ تعهدات پیش رو: $upcomingText ریال\n'
                        'میانگین مبلغ: $averageText ریال',
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReportChequesPage(
                              title: 'چک‌های ${row.accountTitle}',
                              filter: ReportChequeFilter(
                                bankAccountId: row.bankAccountId,
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
