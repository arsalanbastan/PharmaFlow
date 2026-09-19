import 'package:flutter_test/flutter_test.dart';
import 'package:pharmaflow/features/dashboard/presentation/widgets/jalali_commitment_calendar_view.dart';

void main() {
  test('left swipe opens next month in the RTL calendar', () {
    expect(
      commitmentCalendarMonthDelta(distance: -60, velocity: -200),
      -1,
    );
  });

  test('right swipe opens previous month in the RTL calendar', () {
    expect(
      commitmentCalendarMonthDelta(distance: 60, velocity: 200),
      1,
    );
  });
}
