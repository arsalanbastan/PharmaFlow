import 'package:flutter/material.dart';

class DiagnosticsRow extends StatelessWidget {
  const DiagnosticsRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(value, textAlign: TextAlign.left)),
          const SizedBox(width: 10),
          Text(
            label,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
