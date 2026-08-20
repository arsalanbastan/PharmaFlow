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
      body: const Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DashboardHeader(),
              SizedBox(height: 8),
              TomorrowCommitmentCard(),
              SizedBox(height: 8),
              Expanded(child: CommitmentPeriodList(fillAvailableHeight: true)),
              SizedBox(height: 5),
              UnregisteredChequesCard(),
            ],
          ),
        ),
      ),
    );
  }
}
