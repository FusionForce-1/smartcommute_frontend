// lib/utils/time_ago.dart

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Just now", "2 min ago", "1 hr ago", "5 hrs ago", "Yesterday", "Oct 3".
String timeAgo(DateTime time, {DateTime? now}) {
  final current = (now ?? DateTime.now()).toLocal();
  final local = time.toLocal();
  final minutes = current.difference(local).inMinutes;

  if (minutes < 1) return 'Just now';
  if (minutes < 60) return '$minutes min ago';
  final hours = minutes ~/ 60;
  if (hours < 24) return '$hours ${hours == 1 ? 'hr' : 'hrs'} ago';
  if (hours < 48) return 'Yesterday';
  return '${_months[local.month - 1]} ${local.day}';
}

const _longMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// "October 29, 2026" in local time.
String formatLongDate(DateTime time) {
  final local = time.toLocal();
  return '${_longMonths[local.month - 1]} ${local.day}, ${local.year}';
}
