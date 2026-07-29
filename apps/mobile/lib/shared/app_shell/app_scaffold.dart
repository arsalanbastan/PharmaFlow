import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_bottom_navigation.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.currentDestination,
    required this.body,
    super.key,
  });

  final String title;
  final AppShellDestination currentDestination;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: title.isEmpty
            ? null
            : AppBar(
                title: Text(title),
              ),

        body: SafeArea(
          child: body,
        ),

        bottomNavigationBar: AppBottomNavigation(
          currentDestination: currentDestination,
          onDestinationSelected: (destination) {
            switch (destination) {
              case AppShellDestination.home:
                if (currentDestination != AppShellDestination.home) {
                  context.go('/');
                }

              case AppShellDestination.reports:
                if (currentDestination != AppShellDestination.reports) {
                  context.go('/reports');
                }

              case AppShellDestination.menu:
                if (currentDestination != AppShellDestination.menu) {
                  context.go('/menu');
                }
            }
          },
        ),
      ),
    );
  }
}