import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/manager_push_device_registration_service.dart';
import '../providers/communication_settings_provider.dart';
import '../widgets/settings_section_card.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool _enabled = true;
  ManagerNotificationMode _orderMode = ManagerNotificationMode.audible;
  ManagerNotificationMode _chequeMode = ManagerNotificationMode.audible;
  ManagerNotificationMode _cashPaymentMode = ManagerNotificationMode.audible;

  ManagerPushDeviceRegistrationService get _service =>
      ManagerPushDeviceRegistrationService(
        apiClient: ref.read(apiClientProvider),
      );

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final preferences = await _service.loadNotificationPreferences();

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = preferences.notificationsEnabled;
        _orderMode = preferences.orderMode;
        _chequeMode = preferences.chequeMode;
        _cashPaymentMode = preferences.cashPaymentMode;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = 'بارگذاری تنظیمات اعلان‌ها انجام نشد.';
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final saved = await _service.updateNotificationPreferences(
        ManagerNotificationPreferences(
          notificationsEnabled: _enabled,
          orderMode: _orderMode,
          chequeMode: _chequeMode,
          cashPaymentMode: _cashPaymentMode,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _enabled = saved.notificationsEnabled;
        _orderMode = saved.orderMode;
        _chequeMode = saved.chequeMode;
        _cashPaymentMode = saved.cashPaymentMode;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تنظیمات اعلان‌ها ذخیره شد.')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'ذخیره تنظیمات اعلان‌ها انجام نشد.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _modeLabel(ManagerNotificationMode mode) {
    return switch (mode) {
      ManagerNotificationMode.audible => 'روشن',
      ManagerNotificationMode.silent => 'بی‌صدا',
      ManagerNotificationMode.off => 'خاموش',
    };
  }

  Widget _modeSelector({
    required String title,
    required String subtitle,
    required IconData icon,
    required ManagerNotificationMode value,
    required ValueChanged<ManagerNotificationMode> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, textAlign: TextAlign.right),
      subtitle: Text(subtitle, textAlign: TextAlign.right),
      trailing: DropdownButton<ManagerNotificationMode>(
        value: value,
        onChanged: !_enabled || _saving
            ? null
            : (next) {
                if (next != null) {
                  onChanged(next);
                }
              },
        items: ManagerNotificationMode.values
            .map(
              (mode) => DropdownMenuItem<ManagerNotificationMode>(
                value: mode,
                child: Text(_modeLabel(mode)),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('اعلان‌ها')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    SettingsSectionCard(
                      title: 'اعلان‌های این دستگاه',
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _enabled,
                          onChanged: _saving
                              ? null
                              : (value) {
                                  setState(() {
                                    _enabled = value;
                                  });
                                },
                          title: const Text(
                            'همه اعلان‌ها',
                            textAlign: TextAlign.right,
                          ),
                          subtitle: const Text(
                            'با خاموش کردن این گزینه هیچ اعلان عملیاتی روی این دستگاه ارسال نمی‌شود.',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    SettingsSectionCard(
                      title: 'نوع اعلان',
                      children: [
                        _modeSelector(
                          title: 'سفارش جدید',
                          subtitle: 'اعلان ثبت درخواست سفارش توسط کارکنان',
                          icon: Icons.shopping_cart_outlined,
                          value: _orderMode,
                          onChanged: (value) {
                            setState(() {
                              _orderMode = value;
                            });
                          },
                        ),
                        const Divider(),
                        _modeSelector(
                          title: 'ثبت چک',
                          subtitle:
                              'زیرساخت تنظیمات آماده است؛ ارسال در مرحله بعد فعال می‌شود.',
                          icon: Icons.receipt_long_outlined,
                          value: _chequeMode,
                          onChanged: (value) {
                            setState(() {
                              _chequeMode = value;
                            });
                          },
                        ),
                        const Divider(),
                        _modeSelector(
                          title: 'ثبت واریزی',
                          subtitle:
                              'زیرساخت تنظیمات آماده است؛ ارسال در مرحله بعد فعال می‌شود.',
                          icon: Icons.account_balance_wallet_outlined,
                          value: _cashPaymentMode,
                          onChanged: (value) {
                            setState(() {
                              _cashPaymentMode = value;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
