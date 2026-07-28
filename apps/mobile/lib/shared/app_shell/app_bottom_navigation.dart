import 'package:flutter/material.dart';

enum AppShellDestination {
  home,
  reports,
  menu,
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.currentDestination,
    required this.onDestinationSelected,
    super.key,
  });

  final AppShellDestination currentDestination;
  final ValueChanged<AppShellDestination> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final compactTheme = Theme.of(context).copyWith(
      visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: compactTheme,
        child: NavigationBar(
          height: 56,
          maintainBottomViewPadding: true,
          selectedIndex: currentDestination.index,
          onDestinationSelected: (index) {
            onDestinationSelected(AppShellDestination.values[index]);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'خانه',
            ),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: 'گزارشات',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_outlined),
              selectedIcon: Icon(Icons.menu),
              label: 'منو',
            ),
          ],
        ),
      ),
    );
  }
}
