// Transit alert + operator profile models — mirror /alerts and
// GET /operators/me on the backend.

import 'fleet.dart' show parseUtc;

enum AlertSeverity {
  info('info', 'Information'),
  warning('warning', 'Warning'),
  critical('critical', 'Critical');

  const AlertSeverity(this.value, this.label);

  /// The value the backend stores.
  final String value;
  final String label;

  static AlertSeverity parse(String? value) => AlertSeverity.values.firstWhere(
        (s) => s.value == value,
        orElse: () => AlertSeverity.info,
      );
}

class TransitAlert {
  const TransitAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.isResolved,
    this.routeId,
    this.routeCode,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final String? routeId; // null = all routes
  final String? routeCode;
  final bool isResolved;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory TransitAlert.fromJson(Map<String, dynamic> json) => TransitAlert(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        severity: AlertSeverity.parse(json['severity'] as String?),
        routeId: json['route_id'] as String?,
        routeCode: json['route_code'] as String?,
        isResolved: json['is_resolved'] as bool? ?? false,
        createdAt: parseUtc(json['created_at']),
        resolvedAt: parseUtc(json['resolved_at']),
      );
}

/// The fields of the Create Transit Alert form.
class NewAlert {
  const NewAlert({
    required this.title,
    required this.message,
    required this.severity,
    this.routeId,
  });

  final String title;
  final String message;
  final AlertSeverity severity;
  final String? routeId;

  Map<String, dynamic> toJson() => {
        'title': title,
        'message': message,
        'severity': severity.value,
        'route_id': routeId,
      };
}

/// GET /operators/me.
class OperatorProfile {
  const OperatorProfile({
    required this.companyName,
    required this.isVerified,
    this.email,
    this.fullName,
    this.franchiseNumber,
    this.contactNumber,
  });

  final String companyName;
  final String? email;
  final String? fullName;
  final String? franchiseNumber;
  final String? contactNumber;
  final bool isVerified;

  factory OperatorProfile.fromJson(Map<String, dynamic> json) => OperatorProfile(
        companyName: json['company_name'] as String? ?? '',
        email: json['email'] as String?,
        fullName: json['full_name'] as String?,
        franchiseNumber: json['franchise_number'] as String?,
        contactNumber: json['contact_number'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
      );

  /// "Cebu City Transport Co." -> "CC"
  String get initials {
    final words = companyName.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? '?' : letters;
  }
}

const List<String> _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _clock(DateTime t) {
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// "Just now", "10 minutes ago", "3 hours ago", "Yesterday, 4:20 PM",
/// "Oct 3, 4:20 PM".
String alertTimeLabel(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ${diff.inMinutes == 1 ? 'minute' : 'minutes'} ago';
  }
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  if (day == today) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (today.difference(day).inDays == 1) return 'Yesterday, ${_clock(time)}';
  final year = time.year == now.year ? '' : ' ${time.year}';
  return '${_months[time.month - 1]} ${time.day}$year, ${_clock(time)}';
}
