import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../pharmaflow_date_picker_utils.dart';

class PharmaFlowDatePickerDayGrid extends StatelessWidget {
  const PharmaFlowDatePickerDayGrid({
    required this.days,
    required this.selectedDate,
    required this.today,
    required this.isDayDisabled,
    required this.onDayTap,
    super.key,
  });

  final List<Jalali?> days;
  final Jalali selectedDate;
  final Jalali today;
  final bool Function(Jalali date) isDayDisabled;
  final ValueChanged<Jalali> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: jalaliWeekdayNames
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: days.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            mainAxisExtent: 36,
          ),
          itemBuilder: (context, index) {
            final day = days[index];

            if (day == null) {
              return const SizedBox.shrink();
            }

            final isDisabled = isDayDisabled(day);
            final isSelected = isSameJalali(day, selectedDate);
            final isToday = isSameJalali(day, today);

            final textColor = isDisabled
                ? theme.disabledColor
                : isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: isDisabled ? null : () => onDayTap(day),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surface,
                    border: isToday && !isSelected
                        ? Border.all(color: theme.colorScheme.primary)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      toPersianDigits(day.day.toString()),
                      style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
