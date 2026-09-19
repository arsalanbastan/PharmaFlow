import 'package:flutter/material.dart';

class PharmaFlowDatePickerHeader extends StatelessWidget {
  const PharmaFlowDatePickerHeader({
    required this.yearLabel,
    required this.monthLabel,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    required this.onYearTap,
    required this.onMonthTap,
    super.key,
  });

  final String yearLabel;
  final String monthLabel;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onYearTap;
  final VoidCallback onMonthTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            _PickerChip(label: yearLabel, onTap: onYearTap),
            _PickerChip(label: monthLabel, onTap: onMonthTap),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            IconButton(
              tooltip: 'ماه بعد',
              onPressed: canGoNext ? onNext : null,
              icon: const Icon(Icons.chevron_right),
            ),
            Expanded(
              child: Text(
                '$monthLabel $yearLabel',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'ماه قبل',
              onPressed: canGoPrevious ? onPrevious : null,
              icon: const Icon(Icons.chevron_left),
            ),
          ],
        ),
      ],
    );
  }
}

class _PickerChip extends StatelessWidget {
  const _PickerChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: theme.textTheme.titleSmall),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
