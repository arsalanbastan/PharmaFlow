import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_preferences_provider.dart';
import '../widgets/settings_section_card.dart';

class CommitmentThresholdSettingsPage extends ConsumerStatefulWidget {
  const CommitmentThresholdSettingsPage({super.key});

  @override
  ConsumerState<CommitmentThresholdSettingsPage> createState() =>
      _CommitmentThresholdSettingsPageState();
}

class _CommitmentThresholdSettingsPageState
    extends ConsumerState<CommitmentThresholdSettingsPage> {
  final _greenController = TextEditingController();
  final _orangeController = TextEditingController();
  final _redController = TextEditingController();
  final _largeAmountController = TextEditingController();

  bool _isSaving = false;
  bool _didInitController = false;
  String? _validationError;

  @override
  void dispose() {
    _greenController.dispose();
    _orangeController.dispose();
    _redController.dispose();
    _largeAmountController.dispose();
    super.dispose();
  }

  int? _parsePositive(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }

    final parsed = int.tryParse(digits);
    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  DashboardThresholds? _validateAndBuild() {
    final green = _parsePositive(_greenController.text);
    final orange = _parsePositive(_orangeController.text);
    final red = _parsePositive(_redController.text);

    if (green == null || orange == null || red == null) {
      setState(() {
        _validationError = 'هر سه مقدار باید عدد مثبت باشند.';
      });
      return null;
    }

    if (!(green < orange && orange < red)) {
      setState(() {
        _validationError =
            'ترتیب مقادیر باید به صورت Green < Orange < Red باشد.';
      });
      return null;
    }

    setState(() {
      _validationError = null;
    });

    return DashboardThresholds(green: green, orange: orange, red: red);
  }

  Future<void> _save() async {
    final validated = _validateAndBuild();
    if (validated == null) {
      return;
    }

    final largeAmountThreshold = _parsePositive(_largeAmountController.text);
    if (largeAmountThreshold == null) {
      setState(() {
        _validationError = 'حد آستانه گزارش مبالغ بزرگ باید عدد مثبت باشد.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(appPreferencesActionsProvider).saveThresholds(validated);
      await ref
          .read(appPreferencesActionsProvider)
          .saveLargeAmountThreshold(largeAmountThreshold);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('سقف دوره‌ها ذخیره شد.')));
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
        appBar: AppBar(title: const Text('سقف دوره‌ها')),
        body: preferencesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              const Center(child: Text('بارگذاری تنظیمات با خطا مواجه شد.')),
          data: (preferences) {
            if (!_didInitController) {
              _greenController.text = preferences.thresholds.green.toString();
              _orangeController.text = preferences.thresholds.orange.toString();
              _redController.text = preferences.thresholds.red.toString();
              _largeAmountController.text = preferences.largeAmountThreshold
                  .toString();
              _didInitController = true;
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                SettingsSectionCard(
                  title: 'تنظیم سقف رنگ‌ها',
                  children: [
                    _numberField('Green Threshold', _greenController),
                    const SizedBox(height: 10),
                    _numberField('Orange Threshold', _orangeController),
                    const SizedBox(height: 10),
                    _numberField('Red Threshold', _redController),
                    const SizedBox(height: 10),
                    _numberField(
                      'Large Amount Report Threshold',
                      _largeAmountController,
                    ),
                    if (_validationError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _validationError!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
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

  Widget _numberField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) {
        if (_validationError != null) {
          setState(() {
            _validationError = null;
          });
        }
      },
    );
  }
}
