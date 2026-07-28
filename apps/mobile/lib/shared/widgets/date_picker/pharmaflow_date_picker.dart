import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import 'src/pharmaflow_date_picker_dialog.dart';
import 'src/pharmaflow_date_picker_utils.dart';

typedef PharmaFlowDateDisabledPredicate = bool Function(Jalali date);

class PharmaFlowDatePickerThemeData {
  const PharmaFlowDatePickerThemeData({
    this.primaryColor,
    this.onPrimaryColor,
    this.surfaceColor,
    this.onSurfaceColor,
  });

  final Color? primaryColor;
  final Color? onPrimaryColor;
  final Color? surfaceColor;
  final Color? onSurfaceColor;
}

class PharmaFlowDatePicker {
  const PharmaFlowDatePicker._();

  static Future<Jalali?> show({
    required BuildContext context,
    required Jalali initialDate,
    required Jalali firstDate,
    required Jalali lastDate,
    Jalali? today,
    bool autoConfirm = false,
    Set<Jalali> disabledDates = const <Jalali>{},
    PharmaFlowDateDisabledPredicate? disabledDatePredicate,
    PharmaFlowDatePickerThemeData theme = const PharmaFlowDatePickerThemeData(),
    bool barrierDismissible = true,
  }) async {
    final normalizedFirst = toDateOnly(firstDate);
    final normalizedLast = toDateOnly(lastDate);

    if (compareJalali(normalizedFirst, normalizedLast) > 0) {
      throw ArgumentError('firstDate must be less than or equal to lastDate.');
    }

    final normalizedDisabled = disabledDates.map(toDateOnly).toSet();

    return showDialog<Jalali>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) {
        return PharmaFlowDatePickerDialog(
          initialDate: toDateOnly(initialDate),
          firstDate: normalizedFirst,
          lastDate: normalizedLast,
          today: toDateOnly(today ?? Jalali.now()),
          autoConfirm: autoConfirm,
          disabledDates: normalizedDisabled,
          disabledDatePredicate: disabledDatePredicate,
          theme: theme,
        );
      },
    );
  }
}
