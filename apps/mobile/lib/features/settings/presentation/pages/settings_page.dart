import 'package:flutter/material.dart';

import 'commitment_threshold_settings_page.dart';
import 'communication_settings_page.dart';
import 'user_profile_settings_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
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
              leading: const Icon(Icons.person_outline),
              title: const Text('کاربران', textAlign: TextAlign.right),
              subtitle: const Text(
                'نام نمایشی کاربر فعال',
                textAlign: TextAlign.right,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const UserProfileSettingsPage(),
                  ),
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
