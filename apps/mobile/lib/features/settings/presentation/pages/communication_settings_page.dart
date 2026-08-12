import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../cheques/presentation/providers/active_cheques_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../reports/presentation/providers/reports_providers.dart';
import '../providers/communication_settings_provider.dart';
import '../widgets/diagnostics_row.dart';
import '../widgets/settings_section_card.dart';

class CommunicationSettingsPage extends ConsumerWidget {
  const CommunicationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(communicationSettingsProvider);
    final notifier = ref.read(communicationSettingsProvider.notifier);
    final syncState = ref.watch(syncStateProvider).valueOrNull;
    final resolvedLastSuccessfulSync =
        syncState?.lastSuccessfulSyncAt ?? state.lastSuccessfulSyncAt;
    final resolvedLastAttempt =
        syncState?.lastSyncAttemptAt ?? state.lastSyncAttemptAt;

    ref.listen(syncStateProvider, (previous, next) {
      final nextState = next.valueOrNull;
      final lastSuccessfulSync = nextState?.lastSuccessfulSyncAt;
      if (lastSuccessfulSync != null) {
        notifier.updateLastSuccessfulSyncAt(lastSuccessfulSync);
      }

      final lastAttempt = nextState?.lastSyncAttemptAt;
      if (lastAttempt != null) {
        notifier.updateLastSyncAttemptAt(lastAttempt);
      }
    });

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
                        label: 'آخرین همگام سازی موفق',
                        value: _formatDateTime(resolvedLastSuccessfulSync),
                      ),
                      DiagnosticsRow(
                        label: 'آخرین تلاش',
                        value: _formatDateTime(resolvedLastAttempt),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final syncService = ref.read(syncServiceProvider);

                          try {
                            final result = await syncService.retryManually();

                            if (!context.mounted) {
                              return;
                            }

                            final text = result.serverUnavailable
                                ? 'عدم دسترسی به سرور'
                                : result.hasFailures
                                ? 'همگام سازی ناقص بود. موفق: ${result.succeeded}، ناموفق: ${result.failed}'
                                : 'همگام سازی انجام شد. موارد موفق: ${result.succeeded}';

                            messenger.showSnackBar(
                              SnackBar(content: Text(text)),
                            );
                          } catch (_) {
                            if (!context.mounted) {
                              return;
                            }

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('همگام سازی با خطا مواجه شد.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync Now'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _onBootstrapPressed(context, ref),
                        icon: const Icon(Icons.storage_outlined),
                        label: const Text('Bootstrap Local Database'),
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
                        label: 'Backend Service',
                        value: state.healthResponse?.service ?? '-',
                      ),
                      DiagnosticsRow(
                        label: 'Backend Version',
                        value: state.healthResponse?.version ?? '-',
                      ),
                      DiagnosticsRow(
                        label: 'Environment',
                        value: state.healthResponse?.environment ?? '-',
                      ),
                      DiagnosticsRow(
                        label: 'Database Status',
                        value:
                            state.healthResponse?.database?.status ??
                            state.databaseStatus,
                      ),
                      DiagnosticsRow(
                        label: 'Server Time',
                        value: _formatDateTime(
                          state.healthResponse?.serverTime,
                        ),
                      ),
                      DiagnosticsRow(
                        label: 'Response Latency',
                        value: state.healthResponse == null
                            ? '-'
                            : _formatDuration(
                                state.healthResponse!.responseDuration,
                              ),
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

  Future<void> _onBootstrapPressed(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Initial Device Setup'),
          content: const Text(
            'This downloads all Companies, Bank Accounts and Cheques\n'
            'from the server and rebuilds the local database.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Bootstrap'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final progress = ValueNotifier<String>('Downloading Companies...');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Initial Device Setup'),
            content: ValueListenableBuilder<String>(
              valueListenable: progress,
              builder: (context, value, _) {
                return Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(value)),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    try {
      progress.value = 'Downloading Companies...';
      await Future<void>.delayed(const Duration(milliseconds: 150));

      progress.value = 'Downloading Bank Accounts...';
      await Future<void>.delayed(const Duration(milliseconds: 150));

      progress.value = 'Downloading Cheques...';
      await Future<void>.delayed(const Duration(milliseconds: 150));

      progress.value = 'Building local database...';
      await ref.read(identityBootstrapServiceProvider).bootstrap();

      progress.value = 'Completed.';

      await ref.read(syncServiceProvider).refreshState();
      _refreshPostBootstrapData(ref);

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Initial Device Setup'),
            content: const Text('Bootstrap completed successfully.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Initial Device Setup'),
            content: Text(error.toString()),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } finally {
      progress.dispose();
    }
  }

  void _refreshPostBootstrapData(WidgetRef ref) {
    ref.invalidate(activeChequesProvider);
    ref.invalidate(activeChequeLookupProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(reportFilteredChequesProvider);
    ref.invalidate(companyPerformanceReportProvider);
    ref.invalidate(upcomingCommitmentsReportProvider);
    ref.invalidate(bankAccountSummaryReportProvider);
    ref.invalidate(sayadStatusReportProvider);
    ref.invalidate(monthlyCommitmentReportProvider);
    ref.invalidate(largeAmountThresholdProvider);
    ref.invalidate(largeAmountChequesReportProvider);
    ref.invalidate(activityReportProvider);
    ref.invalidate(syncStateProvider);
    ref.invalidate(communicationSettingsProvider);
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

  String _formatDuration(Duration value) {
    if (value.inMilliseconds < 1000) {
      return '${value.inMilliseconds} ms';
    }

    final seconds = value.inMilliseconds / 1000;
    return '${seconds.toStringAsFixed(2)} s';
  }
}
