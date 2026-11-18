// Shift time
/// Shift time two
String _two(int n) => n.toString().padLeft(2, '0');

/// Format clock
String formatClock(Duration d) {
  final seconds = d.isNegative ? 0 : d.inSeconds;
  return '${_two(seconds ~/ 3600)}:${_two(seconds ~/ 60 % 60)}:${_two(seconds % 60)}';
}

/// Format time of day
String formatTimeOfDay(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  return '$hour:${_two(local.minute)} ${local.hour < 12 ? 'AM' : 'PM'}';
}

/// Format ETA
String formatEta(int? minutes) {
  if (minutes == null || minutes < 0) return '—';
  return minutes == 0 ? 'Arriving' : '$minutes min';
}
