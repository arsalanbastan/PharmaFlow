import 'package:flutter/material.dart';

class SearchableSelectorField extends StatelessWidget {
  const SearchableSelectorField({
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
    super.key,
  });

  final String label;
  final String? value;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              errorText: errorText,
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              (value == null || value!.trim().isEmpty) ? 'انتخاب کنید' : value!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (value == null || value!.trim().isEmpty)
                  ? theme.textTheme.bodyMedium?.copyWith(
                      color: theme.hintColor,
                    )
                  : theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}