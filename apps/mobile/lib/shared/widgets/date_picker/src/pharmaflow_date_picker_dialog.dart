import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../pharmaflow_date_picker.dart';
import 'pharmaflow_date_picker_utils.dart';
import 'widgets/pharmaflow_date_picker_day_grid.dart';
import 'widgets/pharmaflow_date_picker_header.dart';

class PharmaFlowDatePickerDialog extends StatefulWidget {
  const PharmaFlowDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.today,
    required this.autoConfirm,
    required this.disabledDates,
    required this.disabledDatePredicate,
    required this.theme,
    super.key,
  });

  final Jalali initialDate;
  final Jalali firstDate;
  final Jalali lastDate;
  final Jalali today;
  final bool autoConfirm;
  final Set<Jalali> disabledDates;
  final PharmaFlowDateDisabledPredicate? disabledDatePredicate;
  final PharmaFlowDatePickerThemeData theme;

  @override
  State<PharmaFlowDatePickerDialog> createState() =>
      _PharmaFlowDatePickerDialogState();
}

class _PharmaFlowDatePickerDialogState extends State<PharmaFlowDatePickerDialog> {
  late Jalali _selectedDate;
  late Jalali _displayedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveInitialDate();
    _displayedMonth = Jalali(_selectedDate.year, _selectedDate.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxWidth = math.min(MediaQuery.sizeOf(context).width - 24, 360.0);

    final surfaceColor = widget.theme.surfaceColor ?? colorScheme.surface;
    final onSurfaceColor = widget.theme.onSurfaceColor ?? colorScheme.onSurface;
    final primaryColor = widget.theme.primaryColor ?? colorScheme.primary;
    final onPrimaryColor = widget.theme.onPrimaryColor ?? colorScheme.onPrimary;

    final canGoPrevious = !_isMonthBefore(_displayedMonth, widget.firstDate);
    final canGoNext = !_isMonthAfter(_displayedMonth, widget.lastDate);
    final monthDays = _buildMonthDays(_displayedMonth);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                PharmaFlowDatePickerHeader(
                  yearLabel: toPersianDigits(_displayedMonth.year.toString()),
                  monthLabel: jalaliMonthNames[_displayedMonth.month - 1],
                  canGoPrevious: canGoPrevious,
                  canGoNext: canGoNext,
                  onPrevious: _goPreviousMonth,
                  onNext: _goNextMonth,
                  onYearTap: _showYearSelector,
                  onMonthTap: _showMonthSelector,
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: Container(
                    key: ValueKey<String>(
                      '${_displayedMonth.year}-${_displayedMonth.month}',
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PharmaFlowDatePickerDayGrid(
                      days: monthDays,
                      selectedDate: _selectedDate,
                      today: widget.today,
                      isDayDisabled: _isDisabled,
                      onDayTap: _onDayTapped,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: _isDisabled(widget.today)
                          ? null
                          : () {
                              _onDayTapped(widget.today);
                            },
                      child: const Text('امروز'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('انصراف'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: onPrimaryColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(_selectedDate),
                      child: const Text('تایید'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                DefaultTextStyle(
                  style: theme.textTheme.bodySmall!.copyWith(color: onSurfaceColor),
                  child: Text(
                    formatJalaliYmd(_selectedDate),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Jalali _resolveInitialDate() {
    var candidate = toDateOnly(widget.initialDate);

    if (_isDisabled(candidate)) {
      candidate = toDateOnly(widget.today);
    }

    if (_isDisabled(candidate)) {
      var cursor = widget.firstDate;
      while (!isAfterJalali(cursor, widget.lastDate)) {
        if (!_isDisabled(cursor)) {
          return cursor;
        }
        cursor = cursor.addDays(1);
      }

      return widget.firstDate;
    }

    return candidate;
  }

  bool _isDisabled(Jalali date) {
    if (isBeforeJalali(date, widget.firstDate) ||
        isAfterJalali(date, widget.lastDate)) {
      return true;
    }

    if (widget.disabledDatePredicate?.call(date) == true) {
      return true;
    }

    for (final disabled in widget.disabledDates) {
      if (isSameJalali(disabled, date)) {
        return true;
      }
    }

    return false;
  }

  List<Jalali?> _buildMonthDays(Jalali month) {
    final monthStart = Jalali(month.year, month.month, 1);
    final leading = monthStart.weekDay - 1;

    final items = <Jalali?>[];
    items.addAll(List<Jalali?>.filled(leading, null));

    for (var day = 1; day <= monthStart.monthLength; day++) {
      items.add(Jalali(month.year, month.month, day));
    }

    final trailing = (7 - (items.length % 7)) % 7;
    items.addAll(List<Jalali?>.filled(trailing, null));

    return items;
  }

  void _onDayTapped(Jalali date) {
    if (_isDisabled(date)) {
      return;
    }

    setState(() {
      _selectedDate = toDateOnly(date);
      _displayedMonth = Jalali(date.year, date.month, 1);
    });

    if (widget.autoConfirm) {
      Navigator.of(context).pop(_selectedDate);
    }
  }

  void _goPreviousMonth() {
    final previous = _displayedMonth.addMonths(-1);
    if (_isMonthBefore(previous, widget.firstDate)) {
      return;
    }

    setState(() {
      _displayedMonth = Jalali(previous.year, previous.month, 1);
    });
  }

  void _goNextMonth() {
    final next = _displayedMonth.addMonths(1);
    if (_isMonthAfter(next, widget.lastDate)) {
      return;
    }

    setState(() {
      _displayedMonth = Jalali(next.year, next.month, 1);
    });
  }

  bool _isMonthBefore(Jalali month, Jalali boundary) {
    if (month.year < boundary.year) {
      return true;
    }
    return month.year == boundary.year && month.month <= boundary.month - 1;
  }

  bool _isMonthAfter(Jalali month, Jalali boundary) {
    if (month.year > boundary.year) {
      return true;
    }
    return month.year == boundary.year && month.month >= boundary.month + 1;
  }

  Future<void> _showYearSelector() async {
    final selectedYear = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final years = <int>[
          for (var year = widget.firstDate.year; year <= widget.lastDate.year; year++)
            year,
        ];

        final currentIndex = years.indexOf(_displayedMonth.year);
        final controller = ScrollController(
          initialScrollOffset: currentIndex < 0 ? 0 : currentIndex * 52,
        );

        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: ListView.builder(
              controller: controller,
              itemExtent: 52,
              itemCount: years.length,
              itemBuilder: (context, index) {
                final year = years[index];
                final isCurrent = year == _displayedMonth.year;

                return ListTile(
                  selected: isCurrent,
                  title: Text(
                    toPersianDigits(year.toString()),
                    textAlign: TextAlign.center,
                  ),
                  onTap: () => Navigator.of(context).pop(year),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedYear == null) {
      return;
    }

    final cappedMonth = _capMonthForYear(selectedYear, _displayedMonth.month);
    setState(() {
      _displayedMonth = Jalali(selectedYear, cappedMonth, 1);
    });
  }

  Future<void> _showMonthSelector() async {
    final selectedMonth = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 12,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                mainAxisExtent: 44,
              ),
              itemBuilder: (context, index) {
                final month = index + 1;
                final disabled = _isMonthOutsideRange(_displayedMonth.year, month);
                final isCurrent = month == _displayedMonth.month;

                return FilledButton.tonal(
                  onPressed: disabled
                      ? null
                      : () => Navigator.of(context).pop(month),
                  style: FilledButton.styleFrom(
                    backgroundColor: isCurrent
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  child: Text(jalaliMonthNames[index]),
                );
              },
            ),
          ),
        );
      },
    );

    if (selectedMonth == null) {
      return;
    }

    setState(() {
      _displayedMonth = Jalali(_displayedMonth.year, selectedMonth, 1);
    });
  }

  int _capMonthForYear(int year, int month) {
    var result = month;

    if (year == widget.firstDate.year && result < widget.firstDate.month) {
      result = widget.firstDate.month;
    }

    if (year == widget.lastDate.year && result > widget.lastDate.month) {
      result = widget.lastDate.month;
    }

    return result;
  }

  bool _isMonthOutsideRange(int year, int month) {
    if (year < widget.firstDate.year || year > widget.lastDate.year) {
      return true;
    }

    if (year == widget.firstDate.year && month < widget.firstDate.month) {
      return true;
    }

    if (year == widget.lastDate.year && month > widget.lastDate.month) {
      return true;
    }

    return false;
  }
}
