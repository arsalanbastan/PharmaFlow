import 'package:flutter/material.dart';

import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'داشبورد',
      currentDestination: AppShellDestination.home,
      body: Center(
        child: Text('داشبورد'),
      ),
    );
  }
}
