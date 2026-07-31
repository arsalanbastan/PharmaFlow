import 'package:flutter/material.dart';

import 'communication_settings_page.dart';

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
          ],
        ),
      ),
    );
  }
}
