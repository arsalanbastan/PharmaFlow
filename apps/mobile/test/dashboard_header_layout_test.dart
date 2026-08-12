import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharmaflow/core/sync/sync_state.dart';
import 'package:pharmaflow/features/dashboard/presentation/widgets/dashboard_header.dart';
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
}
