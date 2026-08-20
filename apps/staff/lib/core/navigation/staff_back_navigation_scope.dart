import 'package:flutter/material.dart';

class StaffBackNavigationScope extends StatelessWidget {
  const StaffBackNavigationScope({
    required this.isHome,
    required this.onReturnHome,
    required this.child,
    super.key,
  });

  final bool isHome;
  final VoidCallback onReturnHome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      key: const ValueKey('staff-back-navigation-pop-scope'),
      canPop: isHome,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !isHome) {
          onReturnHome();
        }
      },
      child: child,
    );
  }
}
