import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_scaffold.dart';

import '../providers/dashboard_provider.dart';
import '../widgets/check_status_card.dart';
import '../widgets/dashboard_actions.dart';
import '../widgets/dashboard_bottom_navigation.dart';
import '../widgets/dashboard_header.dart';
import '../widgets/financial_commitments_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(dashboardProvider);

    return AppScaffold(
      padding: false,
      bottomNavigationBar: const DashboardBottomNavigation(),
      child: dashboard.when(
        loading: () => const AppLoading(),

        error: (error, stackTrace) => AppError(
          message: error.toString(),
          onRetry: () => ref.invalidate(dashboardProvider),
        ),

        data: (vm) {
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: DashboardHeader(
                  userName: vm.header.userName,
                  pharmacyName: vm.header.pharmacyName,
                  todayDate: vm.header.todayDate,
                ),
              ),

              if (vm.checkStatus.banks.isEmpty &&
                  vm.financialCommitments.periods.isEmpty)
                const SliverFillRemaining(
                  child: AppEmptyState(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(
                      [
                        CheckStatusCard(
                          viewModel: vm.checkStatus,
                        ),

                        const SizedBox(height: 16),

                        FinancialCommitmentsCard(
                          viewModel: vm.financialCommitments,
                        ),

                        const SizedBox(height: 16),

                        const DashboardActions(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}