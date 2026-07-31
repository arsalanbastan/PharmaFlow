import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/communication_settings_provider.dart';
import '../widgets/diagnostics_row.dart';
import '../widgets/settings_section_card.dart';

class CommunicationSettingsPage extends ConsumerWidget {
  const CommunicationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communicationSettingsProvider);
    final notifier = ref.read(communicationSettingsProvider.notifier);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('ارتباطات')),
        body: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  SettingsSectionCard(
                    title: 'پروفایل سرور',
                    children: [
                      _inputField(
                        label: 'نام پروفایل',
                        initialValue: state.profileName,
                        onChanged: notifier.updateProfileName,
                      ),
                      _inputField(
                        label: 'Host',
                        initialValue: state.host,
                        onChanged: notifier.updateHost,
                      ),
                      _inputField(
                        label: 'Port',
                        initialValue: state.port,
                        keyboardType: TextInputType.number,
                        onChanged: notifier.updatePort,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: state.useHttps,
                        title: const Text('HTTPS'),
                        onChanged: notifier.setUseHttps,
                      ),
                      _inputField(
                        label: 'API Version',
                        initialValue: state.apiVersion,
                        onChanged: notifier.updateApiVersion,
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'شبکه',
                    children: [
                      _inputField(
                        label: 'Connect Timeout (ms)',
                        initialValue: state.connectTimeout,
                        keyboardType: TextInputType.number,
                        onChanged: notifier.updateConnectTimeout,
                      ),
                      _inputField(
                        label: 'Receive Timeout (ms)',
                        initialValue: state.receiveTimeout,
                        keyboardType: TextInputType.number,
                        onChanged: notifier.updateReceiveTimeout,
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'همگام سازی',
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: state.autoSync,
                        title: const Text('Auto Sync'),
                        onChanged: notifier.setAutoSync,
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: state.wifiOnly,
                        title: const Text('WiFi Only'),
                        onChanged: notifier.setWifiOnly,
                      ),
                      DiagnosticsRow(
                        label: 'Last Sync',
                        value: _formatDateTime(state.lastSync),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.sync),
                        label: const Text('Manual Sync (Coming Soon)'),
                      ),
                    ],
                  ),
                  SettingsSectionCard(
                    title: 'عیب یابی ارتباط',
                    children: [
                      FilledButton.icon(
                        onPressed: state.isTesting
                            ? null
                            : () => notifier.testConnection(),
                        icon: const Icon(Icons.health_and_safety_outlined),
                        label: Text(
                          state.isTesting ? 'در حال تست...' : 'Test Connection',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DiagnosticsRow(
                        label: 'Connection Status',
                        value: state.connectionStatus,
                      ),
                      DiagnosticsRow(
                        label: 'Database Status',
                        value: state.databaseStatus,
                      ),
                      DiagnosticsRow(
                        label: 'Response Time',
                        value: state.responseTime == null
                            ? '-'
                            : '${state.responseTime} ms',
                      ),
                      DiagnosticsRow(
                        label: 'Last Successful Check',
                        value: _formatDateTime(state.lastSuccessfulCheck),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: FilledButton.icon(
                      onPressed: state.isSaving ? null : () => notifier.save(),
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        state.isSaving ? 'در حال ذخیره...' : 'ذخیره تنظیمات',
                      ),
                    ),
                  ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        state.errorMessage!,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: keyboardType,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${local.year}/$month/$day $hour:$minute';
  }
}
