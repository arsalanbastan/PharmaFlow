import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shamsi_date/shamsi_date.dart';

import '../../../../core/auth/manager_app_auth_gate.dart';
import '../../../../core/sync/sync_state.dart';
import '../providers/dashboard_provider.dart';
import '../../../settings/presentation/providers/communication_settings_provider.dart';
import '../../../settings/presentation/providers/app_preferences_provider.dart';
import 'dashboard_visuals.dart';

class DashboardHeader extends ConsumerWidget {
  const DashboardHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = Jalali.now();
    final syncStateAsync = ref.watch(syncStateProvider);
    final syncState = syncStateAsync.valueOrNull;
    final statusLabel = _statusLabel(syncState);
    final statusColor = _statusColor(syncState);
    final lastSyncText = _formatDateTime(syncState?.lastSuccessfulSyncAt);
    final lastAttemptText = _formatDateTime(syncState?.lastSyncAttemptAt);
    final lastError = syncState?.lastUserSafeErrorMessage;
    final pendingCount = syncState?.pendingCount ?? 0;
    final failedCount = syncState?.failedCount ?? 0;
    final connectionFailures = syncState?.consecutiveConnectionFailures ?? 0;
    final autoRetrySuspended = syncState?.autoRetrySuspended ?? false;
    final preferences = ref.watch(appPreferencesProvider).valueOrNull;
    final authenticatedDisplayName = ManagerAccessScope.maybeOf(
      context,
    )?.user.displayName.trim();
    final displayName = authenticatedDisplayName?.isNotEmpty == true
        ? authenticatedDisplayName!
        : (preferences?.displayName ?? 'مدیر');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        elevation: 0.3,
        shadowColor: DashboardThemeColors.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(
            color: DashboardThemeColors.border,
            width: 0.8,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [DashboardThemeColors.greenSoft, Colors.white],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -18,
                left: -18,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DashboardThemeColors.headerHighlight,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'سلام $displayName 👋',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                  color: DashboardThemeColors.ink,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  context.pushNamed('jalali-calendar');
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.calendar_month_outlined,
                                      size: 18,
                                      color: DashboardThemeColors.green,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        '${today.year}/${today.month}/${today.day}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: DashboardThemeColors.ink,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth * 0.66,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () async {
                                    if (syncState?.isSyncing == true) {
                                      return;
                                    }

                                    if (failedCount > 0) {
                                      context.pushNamed('sync-failures');
                                      return;
                                    }

                                    final engine = ref.read(
                                      syncServiceProvider,
                                    );
                                    try {
                                      await engine.syncNow();
                                      ref.invalidate(dashboardSummaryProvider);
                                      ref.invalidate(
                                        unregisteredChequesCardProvider,
                                      );
                                    } catch (_) {
                                      // Keep dashboard interaction non-fatal on sync failures.
                                    }
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.cloud_done_outlined,
                                            size: 17,
                                            color: statusColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              statusLabel,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: statusColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          _statusBadge(
                                            label: 'Pending: $pendingCount',
                                            background: const Color(0x1A4CAF50),
                                            textColor: DashboardThemeColors.ink,
                                          ),
                                          _statusBadge(
                                            label: 'Failed: $failedCount',
                                            background: failedCount > 0
                                                ? const Color(0x1AFFEBEE)
                                                : const Color(0x12000000),
                                            borderColor: failedCount > 0
                                                ? Colors.redAccent
                                                : Colors.transparent,
                                            textColor: failedCount > 0
                                                ? Colors.redAccent
                                                : DashboardThemeColors.ink,
                                          ),
                                          if (connectionFailures > 0)
                                            _statusBadge(
                                              label:
                                                  'Connection Fail: $connectionFailures',
                                              background: const Color(
                                                0x1AFFF3E0,
                                              ),
                                              textColor: Colors.orange.shade900,
                                              borderColor: Colors.orange,
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Transform.translate(
                                        offset: const Offset(10, 0),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Stack(
                                            clipBehavior: Clip.none,
                                            alignment: Alignment.centerRight,
                                            children: [
                                              Text(
                                                'آخرین سینک: $lastSyncText',
                                                key: const ValueKey(
                                                  'dashboard-last-sync-text',
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.right,
                                                style: const TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w500,
                                                  color:
                                                      DashboardThemeColors.ink,
                                                ),
                                              ),
                                              Positioned(
                                                right: -16,
                                                child: SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: Center(
                                                    child:
                                                        syncState?.isSyncing ==
                                                            true
                                                        ? const SizedBox(
                                                            width: 11,
                                                            height: 11,
                                                            child: CircularProgressIndicator(
                                                              strokeWidth: 1.6,
                                                              color:
                                                                  DashboardThemeColors
                                                                      .green,
                                                            ),
                                                          )
                                                        : Icon(
                                                            failedCount > 0
                                                                ? Icons
                                                                      .error_outline
                                                                : Icons.sync,
                                                            size: 12,
                                                            color:
                                                                failedCount > 0
                                                                ? Colors
                                                                      .redAccent
                                                                : DashboardThemeColors
                                                                      .green,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Transform.translate(
                                        offset: const Offset(10, 0),
                                        child: Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'آخرین تلاش: $lastAttemptText',
                                            key: const ValueKey(
                                              'dashboard-last-attempt-text',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                            style: const TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: DashboardThemeColors.ink,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (autoRetrySuspended) ...[
                                        const SizedBox(height: 2),
                                        const Text(
                                          'تلاش خودکار متوقف شده است',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        TextButton(
                                          onPressed: () async {
                                            final engine = ref.read(
                                              syncServiceProvider,
                                            );
                                            try {
                                              await engine.retryManually();
                                            } catch (_) {}
                                          },
                                          child: const Text('تلاش مجدد'),
                                        ),
                                      ],
                                      if (lastError != null &&
                                          lastError.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          lastError,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(SyncState? syncState) {
    if (syncState == null) {
      return 'idle';
    }

    return switch (syncState.syncStatus) {
      SyncUiStatus.idle => 'idle',
      SyncUiStatus.checkingServer => 'checkingServer',
      SyncUiStatus.syncing => 'syncing',
      SyncUiStatus.success => 'success',
      SyncUiStatus.serverUnavailable => 'عدم دسترسی به سرور',
      SyncUiStatus.failed => 'failed',
      SyncUiStatus.autoRetrySuspended => 'autoRetrySuspended',
      SyncUiStatus.alreadyRunning => 'alreadyRunning',
    };
  }

  Color _statusColor(SyncState? syncState) {
    switch (_statusLabel(syncState)) {
      case 'syncing':
        return Colors.blue;
      case 'checkingServer':
        return Colors.indigo;
      case 'عدم دسترسی به سرور':
        return Colors.orange;
      case 'failed':
        return Colors.redAccent;
      case 'autoRetrySuspended':
        return Colors.red;
      case 'alreadyRunning':
        return Colors.teal;
      case 'idle':
        return Colors.amber.shade800;
      case 'success':
        return DashboardThemeColors.green;
    }

    return DashboardThemeColors.green;
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) {
      return '-';
    }

    final local = value.toLocal();
    final jalali = Jalali.fromDateTime(local);
    final month = jalali.month.toString().padLeft(2, '0');
    final day = jalali.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '${jalali.year}/$month/$day - $hour:$minute';
  }

  Widget _statusBadge({
    required String label,
    required Color background,
    required Color textColor,
    Color borderColor = Colors.transparent,
    VoidCallback? onTap,
  }) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: content,
    );
  }
}
