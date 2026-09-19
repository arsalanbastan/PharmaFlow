import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../data/models/cash_payment.dart';
import '../../../../shared/widgets/date_picker/pharmaflow_date_picker.dart';
import '../providers/active_cash_payments_provider.dart';
import 'cash_payment_form_page.dart';

class CashPaymentListPage extends ConsumerStatefulWidget {
  const CashPaymentListPage({super.key});

  @override
  ConsumerState<CashPaymentListPage> createState() =>
      _CashPaymentListPageState();
}

class _CashPaymentListPageState extends ConsumerState<CashPaymentListPage> {
  final _searchController = TextEditingController();

  Jalali? _fromDate;
  Jalali? _toDate;

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _pickFromDate() async {
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: _fromDate ?? Jalali.now(),
      firstDate: Jalali(1395, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      autoConfirm: false,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _fromDate = picked;
    });
  }

  Future<void> _pickToDate() async {
    final picked = await PharmaFlowDatePicker.show(
      context: context,
      initialDate: _toDate ?? _fromDate ?? Jalali.now(),
      firstDate: Jalali(1395, 1, 1),
      lastDate: Jalali(1450, 12, 29),
      autoConfirm: false,
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _toDate = picked;
    });
  }

  void _clearDateFilter() {
    setState(() {
      _fromDate = null;
      _toDate = null;
    });
  }

  List<_CashPaymentListItem> _filteredItems(
    ActiveCashPaymentLookupData lookup,
  ) {
    final search = _searchController.text.trim().toLowerCase();

    final from = _fromDate?.toDateTime();

    final to = _toDate?.toDateTime();

    final items = lookup.payments
        .where((payment) => payment.id != null)
        .map(
          (payment) => _CashPaymentListItem(
            payment: payment,
            companyName: lookup.companyNames[payment.companyId] ?? '—',
            bankAccountName:
                lookup.bankAccountNames[payment.bankAccountId] ?? '—',
          ),
        )
        .where((item) {
          if (search.isNotEmpty) {
            final searchable = [
              item.companyName,
              item.bankAccountName,
              item.payment.trackingNumber ?? '',
              item.payment.description ?? '',
              _methodLabel(item.payment.paymentMethod),
            ].join(' ').toLowerCase();

            if (!searchable.contains(search)) {
              return false;
            }
          }

          final localDate = item.payment.paymentDate.toLocal();

          final dateOnly = DateTime(
            localDate.year,
            localDate.month,
            localDate.day,
          );

          if (from != null) {
            final fromOnly = DateTime(from.year, from.month, from.day);

            if (dateOnly.isBefore(fromOnly)) {
              return false;
            }
          }

          if (to != null) {
            final toOnly = DateTime(to.year, to.month, to.day);

            if (dateOnly.isAfter(toOnly)) {
              return false;
            }
          }

          return true;
        })
        .toList(growable: true);

    items.sort((a, b) {
      final byDate = b.payment.paymentDate.compareTo(a.payment.paymentDate);

      if (byDate != 0) {
        return byDate;
      }

      return (b.payment.id ?? 0).compareTo(a.payment.id ?? 0);
    });

    return items;
  }

  Future<void> _refresh() async {
    ref.invalidate(activeCashPaymentLookupProvider);

    await ref.read(activeCashPaymentLookupProvider.future);
  }

  Future<void> _openCreate() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CashPaymentFormPage()),
    );

    if (changed == true) {
      ref.invalidate(activeCashPaymentLookupProvider);
    }
  }

  Future<void> _openEdit(int paymentId) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CashPaymentFormPage(paymentId: paymentId),
      ),
    );

    if (changed == true) {
      ref.invalidate(activeCashPaymentLookupProvider);
    }
  }

  Future<void> _requestDelete(_CashPaymentListItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('حذف واریزی'),
          content: Text(
            'آیا واریزی مربوط به '
            '${item.companyName} حذف شود؟\n\n'
            'پس از همگام‌سازی، حذف روی سرور نیز اعمال می‌شود.',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('انصراف'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final id = item.payment.id;

    if (id == null) {
      return;
    }

    try {
      await ref.read(localCashPaymentRepositoryProvider).requestDelete(id);

      ref.invalidate(activeCashPaymentLookupProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'واریزی در صف حذف قرار گرفت.',
            textAlign: TextAlign.right,
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint(
        'CashPaymentListPage delete failed: '
        '$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'حذف واریزی با خطا مواجه شد.',
            textAlign: TextAlign.right,
          ),
        ),
      );
    }
  }

  String _jalaliText(Jalali? value) {
    if (value == null) {
      return '—';
    }

    final raw =
        '${value.year.toString().padLeft(4, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.day.toString().padLeft(2, '0')}';

    return _toPersianDigits(raw);
  }

  String _paymentDateText(DateTime value) {
    final jalali = Jalali.fromDateTime(value.toLocal());

    return _jalaliText(jalali);
  }

  String _amountText(int amount) {
    final formatted = NumberFormat.decimalPattern('en').format(amount);

    return _toPersianDigits(formatted);
  }

  String _toPersianDigits(String value) {
    const english = '0123456789';

    const persian = '۰۱۲۳۴۵۶۷۸۹';

    var result = value;

    for (var index = 0; index < 10; index++) {
      result = result.replaceAll(english[index], persian[index]);
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final lookupAsync = ref.watch(activeCashPaymentLookupProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('واریزی‌ها')),
        floatingActionButton: FloatingActionButton(
          onPressed: _openCreate,
          child: const Icon(Icons.add),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(
                  hintText: 'جستجو بر اساس شرکت، حساب یا شماره پیگیری...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickFromDate,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('از: ${_jalaliText(_fromDate)}'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickToDate,
                      icon: const Icon(Icons.event, size: 18),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('تا: ${_jalaliText(_toDate)}'),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _clearDateFilter,
                    tooltip: 'پاک کردن فیلتر تاریخ',
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lookupAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    const SizedBox(height: 120),
                    const Center(
                      child: Text('بارگذاری واریزی‌ها با خطا مواجه شد.'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: FilledButton(
                        onPressed: () {
                          ref.invalidate(activeCashPaymentLookupProvider);
                        },
                        child: const Text('تلاش مجدد'),
                      ),
                    ),
                  ],
                ),
                data: (lookup) {
                  final items = _filteredItems(lookup);

                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 140),
                          Center(
                            child: Text(
                              _searchController.text.trim().isEmpty &&
                                      _fromDate == null &&
                                      _toDate == null
                                  ? 'هنوز واریزی ثبت نشده است.'
                                  : 'موردی یافت نشد.',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];

                        final payment = item.payment;

                        return Card(
                          child: ListTile(
                            onTap: () => _openEdit(payment.id!),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.companyName,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_amountText(payment.amountRial)} ریال',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                'تاریخ: ${_paymentDateText(payment.paymentDate)}\n'
                                'روش: ${_methodLabel(payment.paymentMethod)}\n'
                                'حساب: ${item.bankAccountName}'
                                '${payment.trackingNumber == null ? '' : '\nپیگیری: ${payment.trackingNumber}'}',
                                textAlign: TextAlign.right,
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  await _openEdit(payment.id!);
                                }

                                if (value == 'delete') {
                                  await _requestDelete(item);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('ویرایش'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('حذف'),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _methodLabel(CashPaymentMethod method) {
  switch (method) {
    case CashPaymentMethod.bankDeposit:
      return 'واریز به حساب';

    case CashPaymentMethod.posPayment:
      return 'پرداخت توسط پوز';
  }
}

class _CashPaymentListItem {
  const _CashPaymentListItem({
    required this.payment,
    required this.companyName,
    required this.bankAccountName,
  });

  final CashPayment payment;
  final String companyName;
  final String bankAccountName;
}
