import 'package:flutter/material.dart';

import '../../../../core/auth/manager_app_auth_gate.dart';

import 'commitment_threshold_settings_page.dart';
import 'notification_settings_page.dart';
import 'order_settings_page.dart';
import 'communication_settings_page.dart';
import 'software_update_settings_page.dart';
import 'users_access_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final access = ManagerAccessScope.maybeOf(context);

    if (access != null && !access.user.isManager) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: const Text('تنظیمات')),
          body: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'تنظیمات سیستم فقط برای مدیر قابل دسترسی است.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تنظیمات')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.wifi_tethering_outlined),
              title: const Text('ارتباطات', textAlign: TextAlign.right),
              subtitle: const Text(
                'پروفایل سرور و تنظیمات ارتباط',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommunicationSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text(
                'کاربران و دسترسی‌ها',
                textAlign: TextAlign.right,
              ),
              subtitle: const Text(
                'تعریف کاربر، سطح دسترسی، رمز عبور و سوابق فعالیت',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsersAccessPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('اعلان‌ها', textAlign: TextAlign.right),
              subtitle: const Text(
                'روشن، بی‌صدا یا خاموش کردن اعلان‌ها',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.system_update_alt),
              title: const Text(
                'بروزرسانی نرم‌افزار',
                textAlign: TextAlign.right,
              ),
              subtitle: const Text(
                'بررسی نسخه جدید PharmaFlow',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SoftwareUpdateSettingsPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('تنظیمات سفارشات', textAlign: TextAlign.right),
              subtitle: const Text(
                'تعداد روز لازم برای قرار گرفتن در فهرست کسری‌ها',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrderSettingsPage()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('سقف دوره‌ها', textAlign: TextAlign.right),
              subtitle: const Text(
                'آستانه‌های رنگ‌بندی تعهدات داشبورد',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CommitmentThresholdSettingsPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
