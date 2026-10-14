import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/utils/shift_time.dart';

void main() {
  test('formatClock pads hours, minutes and seconds', () {
    expect(formatClock(const Duration(hours: 1, minutes: 20, seconds: 4)), '01:20:04');
    expect(formatClock(Duration.zero), '00:00:00');
    expect(formatClock(const Duration(seconds: -5)), '00:00:00');
  });

  test('formatTimeOfDay uses a 12-hour clock', () {
    expect(formatTimeOfDay(DateTime(2026, 10, 12, 8, 30)), '8:30 AM');
    expect(formatTimeOfDay(DateTime(2026, 10, 12, 0, 5)), '12:05 AM');
    expect(formatTimeOfDay(DateTime(2026, 10, 12, 12, 0)), '12:00 PM');
    expect(formatTimeOfDay(DateTime(2026, 10, 12, 21, 50)), '9:50 PM');
  });

  test('formatEta', () {
    expect(formatEta(4), '4 min');
    expect(formatEta(0), 'Arriving');
    expect(formatEta(-1), '—');
    expect(formatEta(null), '—');
  });
}
