import 'package:freezed_annotation/freezed_annotation.dart';

part 'today_check.freezed.dart';
part 'today_check.g.dart';

@freezed
class TodayCheck with _$TodayCheck {
  const factory TodayCheck({
    required int bankId,

    required String bankName,

    required int totalAmount,

    required int chequeCount,
  }) = _TodayCheck;

  factory TodayCheck.fromJson(
    Map<String, dynamic> json,
  ) =>
      _$TodayCheckFromJson(json);
}