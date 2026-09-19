import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'communication_settings_provider.dart';

class DashboardThresholds {
  const DashboardThresholds({
    required this.green,
    required this.orange,
    required this.red,
  });

  final int green;
  final int orange;
  final int red;
}

class AppPreferences {
  const AppPreferences({
    required this.displayName,
    required this.thresholds,
    required this.largeAmountThreshold,
  });

  final String displayName;
  final DashboardThresholds thresholds;
  final int largeAmountThreshold;
}

const DashboardThresholds defaultDashboardThresholds = DashboardThresholds(
  green: 6000000000,
  orange: 7000000000,
  red: 8000000000,
);

final appPreferencesProvider = FutureProvider<AppPreferences>((ref) async {
  final repository = ref.watch(connectionSettingsRepositoryProvider);
  final settings = await repository.load();

  return AppPreferences(
    displayName: settings.displayName.trim().isEmpty
        ? 'ارسلان'
        : settings.displayName.trim(),
    thresholds: DashboardThresholds(
      green: settings.greenThreshold,
      orange: settings.orangeThreshold,
      red: settings.redThreshold,
    ),
    largeAmountThreshold: settings.largeAmountThreshold,
  );
});

class AppPreferencesActions {
  const AppPreferencesActions(this._ref);

  final Ref _ref;

  Future<void> saveDisplayName(String value) async {
    final trimmed = value.trim();
    final repository = _ref.read(connectionSettingsRepositoryProvider);
    final current = await repository.load();

    await repository.save(
      current.copyWith(displayName: trimmed.isEmpty ? 'ارسلان' : trimmed),
    );

    _ref.invalidate(appPreferencesProvider);
  }

  Future<void> saveThresholds(DashboardThresholds thresholds) async {
    final repository = _ref.read(connectionSettingsRepositoryProvider);
    final current = await repository.load();

    await repository.save(
      current.copyWith(
        greenThreshold: thresholds.green,
        orangeThreshold: thresholds.orange,
        redThreshold: thresholds.red,
      ),
    );

    _ref.invalidate(appPreferencesProvider);
  }

  Future<void> saveLargeAmountThreshold(int threshold) async {
    final repository = _ref.read(connectionSettingsRepositoryProvider);
    final current = await repository.load();

    await repository.save(current.copyWith(largeAmountThreshold: threshold));

    _ref.invalidate(appPreferencesProvider);
  }
}

final appPreferencesActionsProvider = Provider<AppPreferencesActions>((ref) {
  return AppPreferencesActions(ref);
});
