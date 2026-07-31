import 'package:flutter/material.dart';

import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';

import '../widgets/dashboard_header.dart';
import '../widgets/tomorrow_commitment_card.dart';
import '../widgets/commitment_period_list.dart';
import '../widgets/unregistered_cheques_card.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: '',

      currentDestination: AppShellDestination.home,

      body: Directionality(
        textDirection: TextDirection.rtl,

        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,

            children: const [
              DashboardHeader(),

              SizedBox(height: 8),

              TomorrowCommitmentCard(),

              SizedBox(height: 8),

              CommitmentPeriodList(),

              SizedBox(height: 8),

              UnregisteredChequesCard(),
            ],
          ),
        ),
      ),
    );
  }
}
