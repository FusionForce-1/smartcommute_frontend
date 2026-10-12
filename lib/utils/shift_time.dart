// lib/utils/shift_time.dart
//
// Time formats used on the driver's shift screens.

String _two(int n) => n.toString().padLeft(2, '0');

/// 1:20:04 → "01:20:04".
String formatClock(Duration d) {
  final seconds = d.isNegative ? 0 : d.inSeconds;
  return '${_two(seconds ~/ 3600)}:${_two(seconds ~/ 60 % 60)}:${_two(seconds % 60)}';
}

/// Local time of day, e.g. "8:30 AM".
String formatTimeOfDay(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${_two(local.minute)} ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// Minutes to the next stop from the live feed: "4 min", "Arriving",
/// or "—" when unknown (null or -1).
String formatEta(int? minutes) {
  if (minutes == null || minutes < 0) return '—';
  return minutes == 0 ? 'Arriving' : '$minutes min';
}
