import 'package:flutter/material.dart';

import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'گزارشات',
      currentDestination: AppShellDestination.reports,
      body: Center(
        child: Text('گزارشات (به زودی)'),
      ),
    );
  }
}
