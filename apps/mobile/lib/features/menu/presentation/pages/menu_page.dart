import 'package:flutter/material.dart';

import '../../../bank_accounts/presentation/pages/bank_account_list_page.dart';
import '../../../cheques/presentation/pages/cheque_list_page.dart';
import '../../../company/presentation/pages/company_list_page.dart';
import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';

class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
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
            leading: const Icon(Icons.person_outline),
            title: const Text('کاربران', textAlign: TextAlign.right),
            onTap: () => _open(
              context,
              const _ModulePlaceholderPage(title: 'کاربران'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('تنظیمات', textAlign: TextAlign.right),
            onTap: () => _open(
              context,
              const _ModulePlaceholderPage(title: 'تنظیمات'),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _ModulePlaceholderPage extends StatelessWidget {
  const _ModulePlaceholderPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Text(
            '$title (به زودی)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ),
    );
  }
}
