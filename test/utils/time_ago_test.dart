import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/utils/time_ago.dart';

void main() {
  final now = DateTime(2026, 10, 12, 12);
  String ago(Duration d) => timeAgo(now.subtract(d), now: now);

  test('formats recent times like the design', () {
    expect(ago(const Duration(seconds: 20)), 'Just now');
    expect(ago(const Duration(minutes: 2)), '2 min ago');
    expect(ago(const Duration(hours: 1)), '1 hr ago');
    expect(ago(const Duration(hours: 5)), '5 hrs ago');
    expect(ago(const Duration(hours: 30)), 'Yesterday');
    expect(ago(const Duration(days: 9)), 'Oct 3');
  });
}
