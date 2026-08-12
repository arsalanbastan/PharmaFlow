import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../dashboard/presentation/pages/jalali_commitment_calendar_page.dart';
import '../../../../shared/app_shell/app_bottom_navigation.dart';
import '../../../../shared/app_shell/app_scaffold.dart';
import 'activity_report_page.dart';
import 'bank_account_summary_report_page.dart';
import 'company_performance_report_page.dart';
import 'large_amount_report_page.dart';
import 'monthly_commitment_report_page.dart';
import 'sayad_status_report_page.dart';
import 'upcoming_commitments_report_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

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
        title: 'گزارشات',
        currentDestination: AppShellDestination.reports,
        body: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          children: [
            _ReportShortcutCard(
              title: 'گزارش تقویم تعهدات',
              subtitle: 'نمایش تقویم تعهدات (همان تقویم داشبورد)',
              icon: Icons.calendar_month_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const JalaliCommitmentCalendarPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش عملکرد شرکت‌ها',
              subtitle:
                  'تعداد، جمع، میانگین، صیاد، لغو، وصول، نزدیک‌ترین سررسید',
              icon: Icons.business_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CompanyPerformanceReportPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش تعهدات پیش رو',
              subtitle: 'امروز، فردا، ۷ روز آینده، ۳۰ روز آینده',
              icon: Icons.upcoming_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UpcomingCommitmentsReportPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش حساب‌های بانکی',
              subtitle: 'خلاصه عملکرد هر حساب بانکی',
              icon: Icons.account_balance_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BankAccountSummaryReportPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش وضعیت صیاد',
              subtitle: 'ثبت شده/ثبت نشده، درصد ثبت، شرکت‌های پرریسک',
              icon: Icons.verified_user_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SayadStatusReportPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش ماهانه تعهدات',
              subtitle: 'تجمیع ماهانه بر اساس ماه شمسی',
              icon: Icons.date_range_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const MonthlyCommitmentReportPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش مبالغ بزرگ',
              subtitle: 'چک‌های بالاتر از آستانه تنظیمات',
              icon: Icons.trending_up_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LargeAmountReportPage(),
                  ),
                );
              },
            ),
            _ReportShortcutCard(
              title: 'گزارش فعالیت روزانه',
              subtitle: 'ایجاد، به‌روزرسانی، حذف، همگام‌سازی و خطاها',
              icon: Icons.insights_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ActivityReportPage()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportShortcutCard extends StatelessWidget {
  const _ReportShortcutCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
