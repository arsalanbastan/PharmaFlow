import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../../cheques/presentation/pages/cheque_details_page.dart';
import '../providers/reports_providers.dart';

class ReportChequesPage extends ConsumerStatefulWidget {
  const ReportChequesPage({
    required this.title,
    required this.filter,
    super.key,
  });

  final String title;
  final ReportChequeFilter filter;

  @override
  ConsumerState<ReportChequesPage> createState() => _ReportChequesPageState();
}

class _ReportChequesPageState extends ConsumerState<ReportChequesPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(reportFilteredChequesProvider(widget.filter));

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(reportFilteredChequesProvider(widget.filter));
            await ref.read(reportFilteredChequesProvider(widget.filter).future);
          },
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('بارگذاری چک‌ها با خطا مواجه شد.')),
              ],
            ),
            data: (data) {
              final search = _searchController.text.trim().toLowerCase();
              final filtered = data.cheques
                  .where((cheque) {
                    if (search.isEmpty) {
                      return true;
                    }

                    final companyName =
                        (data.companyNames[cheque.companyId] ?? '')
                            .toLowerCase();
                    final chequeNumber = cheque.chequeNumber.toLowerCase();
                    final bankName =
                        (data.bankAccountNames[cheque.bankAccountId] ?? '')
                            .toLowerCase();

                    return companyName.contains(search) ||
                        chequeNumber.contains(search) ||
                        bankName.contains(search);
                  })
                  .toList(growable: false);

              if (data.cheques.isEmpty) {
                return ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('چکی برای این گزارش وجود ندارد.')),
                  ],
                );
              }

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
                          hintText: 'جستجو بر اساس شرکت، بانک یا شماره چک...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    );
                  }

                  final cheque = filtered[index - 1];
                  final dueJalali = Jalali.fromDateTime(cheque.dueDate);
                  final issueJalali = Jalali.fromDateTime(cheque.issueDate);
                  final amountText = NumberFormat.decimalPattern(
                    'en',
                  ).format(cheque.amountRial);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ChequeDetailsPage(chequeId: cheque.id),
                          ),
                        );
                      },
                      title: Text('چک ${cheque.chequeNumber}'),
                      subtitle: Text(
                        'شرکت: ${data.companyNames[cheque.companyId] ?? '—'}\n'
                        'بانک: ${data.bankAccountNames[cheque.bankAccountId] ?? '—'}\n'
                        'سررسید: ${_jalaliText(dueJalali)} | صدور: ${_jalaliText(issueJalali)}',
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$amountText ریال'),
                          const SizedBox(height: 4),
                          Text(
                            cheque.isRegisteredInSayad ? 'ثبت شده' : 'ثبت نشده',
                            style: TextStyle(
                              fontSize: 12,
                              color: cheque.isRegisteredInSayad
                                  ? Colors.green.shade700
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
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

  String _jalaliText(Jalali value) {
    final formatted =
        '${value.year.toString().padLeft(4, '0')}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';
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
