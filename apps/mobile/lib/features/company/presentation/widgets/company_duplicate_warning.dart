import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../data/models/company.dart';
import '../../../../core/utils/company_name_normalizer.dart';

class CompanyDuplicateWarning extends StatelessWidget {
  const CompanyDuplicateWarning({
    super.key,
    required this.input,
    required this.companies,
  });

  final String input;
  final List<Company> companies;

  @override
  Widget build(BuildContext context) {
    if (input.trim().isEmpty || companies.isEmpty) {
      return const SizedBox.shrink();
    }

    final normalizedInput =
        CompanyNameNormalizer.normalize(input);

    final hasExactMatch = companies.any(
      (company) =>
          CompanyNameNormalizer.normalize(company.name) ==
          normalizedInput,
    );

    final color = hasExactMatch
        ? Colors.red.shade100
        : Colors.amber.shade100;

    final iconColor = hasExactMatch
        ? Colors.red
        : Colors.orange;

    final title = hasExactMatch
        ? 'این شرکت قبلاً ثبت شده است.'
        : 'شرکت‌های مشابه پیدا شدند.';

    return Container(
      margin: const EdgeInsets.only(
        top: AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style:
                      AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.sm,
          ),
          ...companies.map(
            (company) => Padding(
              padding: const EdgeInsets.only(
                bottom: 4,
              ),
              child: Text(
                "• ${company.name}",
                style:
                    AppTextStyles.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}