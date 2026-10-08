// Operator dashboard models — mirror GET /fleet, GET /routes and
// GET /announcements on the backend.

/// Backend timestamps are UTC but may be sent without a timezone suffix.
DateTime? parseUtc(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(value);
  return DateTime.tryParse(hasZone ? value : '${value}Z')?.toLocal();
}

/// One row of GET /fleet.
class FleetVehicle {
  const FleetVehicle({
    required this.vehicleId,
    required this.plateNumber,
    required this.routeId,
    required this.status,
    required this.suspended,
    required this.routeStatus,
    this.crowdLevel,
    this.lastPing,
  });

  final String vehicleId;
  final String plateNumber;
  final String routeId;
  final String status; // active | inactive | maintenance
  final bool suspended; // set when the operator's subscription lapses
  final String routeStatus; // active | suspended | congested
  final String? crowdLevel; // low | medium | high
  final DateTime? lastPing;

  factory FleetVehicle.fromJson(Map<String, dynamic> json) {
    final position = json['last_position'];
    return FleetVehicle(
      vehicleId: json['vehicle_id'] as String,
      plateNumber: json['plate_number'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      status: (json['status'] as String? ?? 'active').toLowerCase(),
      suspended: json['suspended'] as bool? ?? false,
      routeStatus: (json['route_status'] as String? ?? 'active').toLowerCase(),
      crowdLevel: json['crowd_level'] as String?,
      lastPing: position is Map ? parseUtc(position['timestamp']) : null,
    );
  }

  /// In service: active, not suspended, and its route is not suspended.
  bool get isActive => status == 'active' && !suspended && routeStatus != 'suspended';

  /// Sent a GPS position within [window] of [now].
  bool hasRecentPing(DateTime now, {Duration window = const Duration(minutes: 10)}) =>
      lastPing != null && now.difference(lastPing!) <= window;
}

/// The parts of GET /routes the dashboard needs.
class RouteSummary {
  const RouteSummary({required this.id, required this.code, required this.name});

  final String id;
  final String code;
  final String name;

  factory RouteSummary.fromJson(Map<String, dynamic> json) => RouteSummary(
        id: json['id'] as String,
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );

  /// "J02 – Talamban"
  String get label => [code, name].where((s) => s.isNotEmpty).join(' – ');
}

class Announcement {
  const Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.targetRole,
    this.createdAt,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String message;
  final String? targetRole; // null = everyone
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        targetRole: json['target_role'] as String?,
        createdAt: parseUtc(json['created_at']),
        expiresAt: parseUtc(json['expires_at']),
      );
}

/// "Just now", "2 min ago", "3 hr ago", "5 days ago".
String timeAgo(DateTime time, DateTime now) {
  final diff = now.difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hr ago';
  final days = diff.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}
