import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaflow/core/auth/manager_app_auth_gate.dart';
import 'package:pharmaflow/core/sync/sync_state.dart';
import 'package:pharmaflow/features/dashboard/presentation/widgets/dashboard_header.dart';
import 'package:pharmaflow/features/orders/data/manager_orders_auth_service.dart';
import 'package:pharmaflow/features/settings/presentation/providers/app_preferences_provider.dart';
import 'package:pharmaflow/features/settings/presentation/providers/communication_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const names = <String>['ارسلان', 'ارسلان بستان', 'کاربر با نام بسیار طولانی'];
  const widths = <double>[320, 360, 400];

  for (final width in widths) {
    for (final name in names) {
      testWidgets(
        'DashboardHeader stays inside card at width $width for name "$name"',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, 220));
          addTearDown(() => tester.binding.setSurfaceSize(null));

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                appPreferencesProvider.overrideWith(
                  (ref) async => AppPreferences(
                    displayName: name,
                    thresholds: defaultDashboardThresholds,
                    largeAmountThreshold: 500000000,
                  ),
                ),
                syncStateProvider.overrideWith(
                  (ref) => Stream.value(const SyncState.initial()),
                ),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(16),
                    child: DashboardHeader(),
                  ),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.byType(DashboardHeader), findsOneWidget);
          expect(find.textContaining('سلام'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('DashboardHeader prefers the authenticated user display name', (
    tester,
  ) async {
    const authenticatedUser = ManagerOrdersAuthUser(
      userId: '11111111-1111-4111-8111-111111111111',
      username: 'arsalan',
      displayName: 'نام نمایشی مدیر',
      role: 'MANAGER',
      permissions: ManagerOrdersAuthPermissions.managerFull,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            (ref) async => const AppPreferences(
              displayName: 'نام قدیمی تنظیمات محلی',
              thresholds: defaultDashboardThresholds,
              largeAmountThreshold: 500000000,
            ),
          ),
          syncStateProvider.overrideWith(
            (ref) => Stream.value(const SyncState.initial()),
          ),
        ],
        child: const MaterialApp(
          home: ManagerAccessScope(
            user: authenticatedUser,
            child: Scaffold(body: DashboardHeader()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('سلام نام نمایشی مدیر'), findsOneWidget);
    expect(find.textContaining('نام قدیمی تنظیمات محلی'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'DashboardHeader formats and aligns compact Jalali sync timestamps',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 220));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final syncState = SyncState(
        isSyncing: false,
        isOnline: true,
        pendingCount: 0,
        failedCount: 0,
        lastSuccessfulSyncAt: DateTime(2026, 8, 13, 13, 12),
        lastSyncAttemptAt: DateTime(2026, 8, 13, 13, 13),
        consecutiveConnectionFailures: 0,
        autoRetrySuspended: false,
        syncStatus: SyncUiStatus.success,
        lastUserSafeErrorMessage: null,
        lastError: null,
        bootstrapRunning: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesProvider.overrideWith(
              (ref) async => AppPreferences(
                displayName: 'ارسلان',
                thresholds: defaultDashboardThresholds,
                largeAmountThreshold: 500000000,
              ),
            ),
            syncStateProvider.overrideWith((ref) => Stream.value(syncState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: EdgeInsets.all(16),
                child: DashboardHeader(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final lastSyncFinder = find.byKey(
        const ValueKey('dashboard-last-sync-text'),
      );
      final lastAttemptFinder = find.byKey(
        const ValueKey('dashboard-last-attempt-text'),
      );

      expect(lastSyncFinder, findsOneWidget);
      expect(lastAttemptFinder, findsOneWidget);
      expect(
        tester.widget<Text>(lastSyncFinder).data,
        'آخرین سینک: 1405/05/22 - 13:12',
      );
      expect(
        tester.widget<Text>(lastAttemptFinder).data,
        'آخرین تلاش: 1405/05/22 - 13:13',
      );
      expect(find.textContaining('آخرین همگام سازی موفق'), findsNothing);

      final lastSyncRect = tester.getRect(lastSyncFinder);
      final lastAttemptRect = tester.getRect(lastAttemptFinder);

      expect(
        (lastSyncRect.right - lastAttemptRect.right).abs(),
        lessThan(0.5),
        reason:
            'Last sync and last attempt text must share the same right edge.',
      );

      final cardRect = tester.getRect(find.byType(Card).first);

      expect(
        lastSyncRect.left,
        greaterThanOrEqualTo(cardRect.left),
        reason: 'Last sync timestamp must stay inside the dashboard card.',
      );
      expect(
        lastAttemptRect.left,
        greaterThanOrEqualTo(cardRect.left),
        reason: 'Last attempt timestamp must stay inside the dashboard card.',
      );
      expect(
        lastSyncRect.right,
        lessThanOrEqualTo(cardRect.right),
        reason: 'Last sync timestamp must stay inside the dashboard card.',
      );
      expect(
        lastAttemptRect.right,
        lessThanOrEqualTo(cardRect.right),
        reason: 'Last attempt timestamp must stay inside the dashboard card.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
