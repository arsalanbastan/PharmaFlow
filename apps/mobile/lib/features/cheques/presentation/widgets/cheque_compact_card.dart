import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/theme/app_colors.dart';

class ChequeCompactCard extends StatelessWidget {
  const ChequeCompactCard({
    required this.id,
    required this.bankName,
    required this.chequeNumber,
    required this.dueDate,
    required this.companyName,
    required this.amountRial,
    required this.isRegistered,
    required this.onToggleRegistered,
    required this.onTap,
    required this.onEdit,
    required this.onCancel,
    super.key,
  });

  final int id;
  final String bankName;
  final String chequeNumber;
  final DateTime dueDate;
  final String companyName;
  final int amountRial;
  final bool isRegistered;
  final ValueChanged<bool> onToggleRegistered;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dueJalali = Jalali.fromDateTime(dueDate);
    final dueDateText = _toPersianDigits(
      '${dueJalali.year.toString().padLeft(4, '0')}/${dueJalali.month.toString().padLeft(2, '0')}/${dueJalali.day.toString().padLeft(2, '0')}',
    );
    final amountText =
        '${_toPersianDigits(NumberFormat.decimalPattern('en').format(amountRial))} ریال';

    final statusBackground = isRegistered
        ? AppColors.success.withValues(alpha: 0.08)
        : AppColors.warning.withValues(alpha: 0.10);
    final statusBorder = isRegistered ? AppColors.success : AppColors.warning;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onEdit();
        } else {
          onCancel();
        }

        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.blue.shade600,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.edit,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'ویرایش',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        color: Colors.red.shade600,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: 6),
            Text(
              'لغو چک',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Container(
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: statusBorder.withValues(alpha: 0.55)),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _fieldBox(
                            context: context,
                            child: Text(
                              chequeNumber,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: _fieldBox(
                            context: context,
                            child: Text(
                              dueDateText,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: _fieldBox(
                            context: context,
                            child: Text(
                              bankName,
                              textAlign: TextAlign.left,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _fieldBox(
                            context: context,
                            child: Text(
                              companyName,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 3,
                          child: _fieldBox(
                            context: context,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                amountText,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          flex: 2,
                          child: _fieldBox(
                            context: context,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: Checkbox(
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(
                                      horizontal: -4,
                                      vertical: -4,
                                    ),
                                    value: isRegistered,
                                    onChanged: (value) =>
                                        onToggleRegistered(value ?? false),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    isRegistered ? 'ثبت شده' : 'ثبت نشده',
                                    textAlign: TextAlign.left,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldBox({
    required BuildContext context,
    required Widget child,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: child,
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