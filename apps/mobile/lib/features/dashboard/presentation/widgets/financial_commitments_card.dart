import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section_title.dart';
import '../viewmodels/financial_commitments_view_model.dart';
import 'commitment_period_tile.dart';

class FinancialCommitmentsCard extends StatelessWidget {
  const FinancialCommitmentsCard({
    super.key,
    required this.viewModel,
  });

  final FinancialCommitmentsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionTitle(
            title: AppStrings.futureCommitments,
            icon: Icons.event_note_rounded,
          ),

          const SizedBox(
            height: AppSpacing.xl,
          ),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: viewModel.periods.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return CommitmentPeriodTile(
                period: viewModel.periods[index],
              );
            },
          ),
        ],
      ),
    );
  }
}