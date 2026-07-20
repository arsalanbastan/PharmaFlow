import 'package:freezed_annotation/freezed_annotation.dart';

import 'commitment_period.dart';
import 'today_check.dart';

part 'dashboard.freezed.dart';
part 'dashboard.g.dart';

@freezed
class Dashboard with _$Dashboard {
  const factory Dashboard({
    /// نام کاربر
    required String userName,

    /// نام داروخانه
    required String pharmacyName,

    /// تاریخ شمسی امروز
    required String todayDate,

    /// جمع کل تعهدات امروز
    required int totalTodayCommitments,

    /// وضعیت چک‌های امروز به تفکیک حساب‌های بانکی
    @Default(<TodayCheck>[])
    List<TodayCheck> todayChecks,

    /// تعهدات مالی آینده
    @Default(<CommitmentPeriod>[])
    List<CommitmentPeriod> commitmentPeriods,
  }) = _Dashboard;

  factory Dashboard.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$DashboardFromJson(json);
}