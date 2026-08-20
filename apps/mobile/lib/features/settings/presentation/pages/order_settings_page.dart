import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../orders/data/order_dashboard_settings.dart';

class OrderSettingsPage extends ConsumerStatefulWidget {
  const OrderSettingsPage({super.key});

  @override
  ConsumerState<OrderSettingsPage> createState() => _OrderSettingsPageState();
}

class _OrderSettingsPageState extends ConsumerState<OrderSettingsPage> {
  final _daysController = TextEditingController();

  bool _didInitialize = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final days = int.tryParse(_daysController.text.trim());

    if (days == null || days < 1 || days > 365) {
      setState(() {
        _error = 'تعداد روز باید بین ۱ تا ۳۶۵ باشد.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref
          .read(orderDashboardSettingsRepositoryProvider)
          .saveShortageDays(days);

      ref.invalidate(orderShortageDaysProvider);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تنظیمات سفارشات ذخیره شد.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(orderShortageDaysProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('تنظیمات سفارشات')),
        body: daysAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              const Center(child: Text('بارگذاری تنظیمات سفارشات انجام نشد.')),
          data: (days) {
            if (!_didInitialize) {
              _daysController.text = days.toString();
              _didInitialize = true;
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _daysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'آستانه کسری',
                    suffixText: 'روز',
                    helperText:
                        'اقلامی که بیش از این مدت در انتظار بمانند، کسری محسوب می‌شوند.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_error != null) {
                      setState(() {
                        _error = null;
                      });
                    }
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'در حال ذخیره...' : 'ذخیره'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
