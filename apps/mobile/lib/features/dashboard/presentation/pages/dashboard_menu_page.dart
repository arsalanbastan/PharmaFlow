import 'package:flutter/material.dart';

import '../../../bank_accounts/presentation/pages/bank_account_list_page.dart';
import '../../../cheques/presentation/pages/cheque_list_page.dart';
import '../../../company/presentation/pages/company_list_page.dart';

class DashboardMenuPage extends StatelessWidget {
  const DashboardMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_DashboardMenuItem>[
      _DashboardMenuItem(
        title: 'حساب های بانکی',
        icon: Icons.account_balance_outlined,
        onTap: () => _openPage(context, const BankAccountListPage()),
      ),
      _DashboardMenuItem(
        title: 'شرکت ها',
        icon: Icons.apartment_outlined,
        onTap: () => _openPage(context, const CompanyListPage()),
      ),
      _DashboardMenuItem(
        title: 'چک ها',
        icon: Icons.receipt_long_outlined,
        onTap: () => _openPage(context, const ChequeListPage()),
      ),
      _DashboardMenuItem(
        title: 'گزارش ها',
        icon: Icons.bar_chart_outlined,
        onTap: () => _openPage(
          context,
          const _ModulePlaceholderPage(title: 'گزارش ها'),
        ),
      ),
      _DashboardMenuItem(
        title: 'تنظیمات',
        icon: Icons.settings_outlined,
        onTap: () => _openPage(
          context,
          const _ModulePlaceholderPage(title: 'تنظیمات'),
        ),
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('داشبورد'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'داشبورد',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final tileWidth = (constraints.maxWidth - 12) / 2;
                        final tileHeight = 92.0;
                        final ratio = tileWidth / tileHeight;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: ratio,
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _MenuTile(item: item);
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openPage(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item});

  final _DashboardMenuItem item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: 22, color: scheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  item.title,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMenuItem {
  const _DashboardMenuItem({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
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
