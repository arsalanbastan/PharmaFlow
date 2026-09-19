import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../data/models/cheque.dart';
import '../../../cheques/presentation/pages/cheque_details_page.dart';
import '../providers/dashboard_provider.dart';
import 'dashboard_visuals.dart';

class UnregisteredChequesCard extends ConsumerStatefulWidget {
  const UnregisteredChequesCard({super.key});

  @override
  ConsumerState<UnregisteredChequesCard> createState() =>
      _UnregisteredChequesCardState();
}

class _UnregisteredChequesCardState
    extends ConsumerState<UnregisteredChequesCard> {
  final Set<int> _pendingChequeIds = <int>{};

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(unregisteredChequesCardProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 0.3,
        shadowColor: DashboardThemeColors.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: DashboardThemeColors.border, width: 0.8),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dataAsync.when(
                data: (data) {
                  final cheques = data.cheques;

                  final title = 'چک‌های ثبت نشده (${cheques.length})';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DashboardThemeColors.ink,
                        ),
                      ),
                      const SizedBox(height: 5),

                      if (cheques.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 6),
                          child: Text(
                            'همه برگه‌های چک ثبت شده‌اند',
                            style: TextStyle(
                              fontSize: 13,
                              color: DashboardThemeColors.muted,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 82,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: cheques.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final cheque = cheques[index];
                              final companyName =
                                  data.companyNames[cheque.companyId] ?? '—';
                              final bankName =
                                  data.bankAccountNames[cheque.bankAccountId] ??
                                  '—';
                              final isPending = _pendingChequeIds.contains(
                                cheque.id,
                              );

                              return SizedBox(
                                width: 280,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => _openChequeDetails(cheque),
                                  child: _UnregisteredChequeItem(
                                    cheque: cheque,
                                    companyName: companyName,
                                    bankName: bankName,
                                    isPending: isPending,
                                    onChecked: () =>
                                        _confirmAndMarkAsRegistered(
                                          cheque: cheque,
                                          companyName: companyName,
                                        ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
                loading: () {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'چک‌های ثبت نشده',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DashboardThemeColors.ink,
                        ),
                      ),
                      SizedBox(height: 10),
                      SizedBox(
                        height: 96,
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                error: (error, stack) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'چک‌های ثبت نشده (0)',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: DashboardThemeColors.ink,
                        ),
                      ),
                      SizedBox(height: 10),
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'خطا در بارگذاری چک‌های ثبت نشده',
                          style: TextStyle(
                            fontSize: 12,
                            color: DashboardThemeColors.muted,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openChequeDetails(Cheque cheque) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ChequeDetailsPage(chequeId: cheque.id)),
    );

    if (!mounted) {
      return;
    }

    ref.invalidate(unregisteredChequesCardProvider);
    ref.invalidate(dashboardSummaryProvider);
  }

  Future<void> _markAsRegistered(Cheque cheque) async {
    if (_pendingChequeIds.contains(cheque.id)) {
      return;
    }

    setState(() {
      _pendingChequeIds.add(cheque.id);
    });

    try {
      final markRegistered = ref.read(markChequeAsRegisteredProvider);
      await markRegistered(cheque);
    } catch (error) {
      if (!mounted) {
        rethrow;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'به‌روزرسانی وضعیت ثبت در صیاد با خطا مواجه شد.',
            textAlign: TextAlign.right,
          ),
        ),
      );

      rethrow;
    } finally {
      if (mounted) {
        setState(() {
          _pendingChequeIds.remove(cheque.id);
        });
      }
    }
  }

  Future<void> _confirmAndMarkAsRegistered({
    required Cheque cheque,
    required String companyName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('ثبت در سامانه صیاد'),
          content: Text(
            'آیا چک شماره ${cheque.chequeNumber} مربوط به شرکت $companyName در سامانه صیاد ثبت شده است؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Yes, Registered'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await _markAsRegistered(cheque);
  }
}

class _UnregisteredChequeItem extends StatelessWidget {
  const _UnregisteredChequeItem({
    required this.cheque,
    required this.companyName,
    required this.bankName,
    required this.isPending,
    required this.onChecked,
  });

  final Cheque cheque;
  final String companyName;
  final String bankName;
  final bool isPending;
  final VoidCallback onChecked;

  @override
  Widget build(BuildContext context) {
    final due = Jalali.fromDateTime(cheque.dueDate);

    final dueText = _toPersianDigits(
      '${due.year.toString().padLeft(4, '0')}/'
      '${due.month.toString().padLeft(2, '0')}/'
      '${due.day.toString().padLeft(2, '0')}',
    );

    final amount = _toPersianDigits(
      NumberFormat.decimalPattern('en').format(cheque.amountRial),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashboardThemeColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: DashboardThemeColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: isPending
                        ? const CircularProgressIndicator(strokeWidth: 2)
                        : Checkbox(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            fillColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return DashboardThemeColors.green;
                              }

                              return Colors.white;
                            }),
                            checkColor: Colors.white,
                            side: const BorderSide(
                              color: DashboardThemeColors.green,
                              width: 1.2,
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            value: false,
                            onChanged: (value) {
                              debugPrint(
                                'ENTER unregistered_cheques_card.dart -> Checkbox.onChanged',
                              );
                              debugPrint(
                                'cheque.id=${cheque.id} current.isRegisteredInSayad=${cheque.isRegisteredInSayad} new.requestedValue=$value',
                              );

                              if (value == true) {
                                onChecked();
                              }

                              debugPrint(
                                'EXIT unregistered_cheques_card.dart -> Checkbox.onChanged',
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'ثبت نشده',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: DashboardThemeColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 7),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoRow('حساب', bankName),
                    const SizedBox(height: 4),
                    _infoRow('شماره چک', cheque.chequeNumber),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _infoRow('سررسید', dueText),
                    const SizedBox(height: 4),
                    _infoRow('مبلغ', '$amount ریال', emphasizeValue: true),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool emphasizeValue = false}) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: DashboardThemeColors.ink,
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: emphasizeValue ? FontWeight.w800 : FontWeight.w400,
              color: emphasizeValue
                  ? DashboardThemeColors.ink
                  : DashboardThemeColors.muted,
            ),
          ),
        ),
      ],
    );
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
