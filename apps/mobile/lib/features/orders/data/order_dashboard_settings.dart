import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int defaultOrderShortageDays = 7;

class OrderDashboardSettingsRepository {
  const OrderDashboardSettingsRepository();

  static const String _shortageDaysKey = 'manager_orders_shortage_days_v1';

  Future<int> loadShortageDays() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getInt(_shortageDaysKey);

    if (value == null || value < 1 || value > 365) {
      return defaultOrderShortageDays;
    }

    return value;
  }

  Future<void> saveShortageDays(int days) async {
    if (days < 1 || days > 365) {
      throw ArgumentError.value(
        days,
        'days',
        'Shortage days must be between 1 and 365.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_shortageDaysKey, days);
  }
}

final orderDashboardSettingsRepositoryProvider =
    Provider<OrderDashboardSettingsRepository>((ref) {
      return const OrderDashboardSettingsRepository();
    });

final orderShortageDaysProvider = FutureProvider<int>((ref) {
  return ref.watch(orderDashboardSettingsRepositoryProvider).loadShortageDays();
});
