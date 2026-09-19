import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../widgets/settings_section_card.dart';

class UserProfileSettingsPage extends ConsumerStatefulWidget {
  const UserProfileSettingsPage({super.key});

  @override
  ConsumerState<UserProfileSettingsPage> createState() =>
      _UserProfileSettingsPageState();
}

class _UserProfileSettingsPageState
    extends ConsumerState<UserProfileSettingsPage> {
  final _nameController = TextEditingController();
  bool _isSaving = false;
  bool _didInitController = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await ref
          .read(appPreferencesActionsProvider)
          .saveDisplayName(_nameController.text);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('نام کاربر ذخیره شد.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferencesAsync = ref.watch(appPreferencesProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('کاربران')),
        body: preferencesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => const Center(
            child: Text('بارگذاری تنظیمات کاربر با خطا مواجه شد.'),
          ),
          data: (preferences) {
            if (!_didInitController) {
              _nameController.text = preferences.displayName;
              _didInitController = true;
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SettingsSectionCard(
                  title: 'کاربر فعال',
                  children: [
                    const Text(
                      'نسخه ۱: یک کاربر فعال پشتیبانی می‌شود.',
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _nameController,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? 'در حال ذخیره...' : 'ذخیره'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
