import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/company/presentation/pages/company_list_page.dart';

class PharmaFlowApp extends StatelessWidget {
  const PharmaFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PharmaFlow',
      debugShowCheckedModeBanner: false,

      theme: AppTheme.lightTheme,

      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },

      home: const CompanyListPage(),
    );
  }
}