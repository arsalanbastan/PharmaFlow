import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../bank_accounts/presentation/pages/bank_account_list_page.dart';
import '../../../cheques/presentation/pages/cheque_list_page.dart';
import '../../../cash_payments/presentation/pages/cash_payment_list_page.dart';
import '../../../company/presentation/pages/company_list_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        context.go('/');
      },
      child: AppScaffold(
        title: 'منو',
        currentDestination: AppShellDestination.menu,
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: const Text('حساب های بانکی', textAlign: TextAlign.right),
              onTap: () => _open(context, const BankAccountListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('شرکت ها', textAlign: TextAlign.right),
              onTap: () => _open(context, const CompanyListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('چک ها', textAlign: TextAlign.right),
              onTap: () => _open(context, const ChequeListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('واریزی‌ها', textAlign: TextAlign.right),
              onTap: () => _open(context, const CashPaymentListPage()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('تنظیمات', textAlign: TextAlign.right),
              onTap: () => _open(context, const SettingsPage()),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
