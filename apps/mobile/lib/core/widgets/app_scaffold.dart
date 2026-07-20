import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.child,
    this.appBar,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.padding = true,
    this.resizeToAvoidBottomInset = true,
  });

  final Widget child;

  final PreferredSizeWidget? appBar;

  final Widget? floatingActionButton;

  final Widget? bottomNavigationBar;

  final bool padding;

  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    Widget body = child;

    if (padding) {
      body = Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: body,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: SafeArea(
        child: body,
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}