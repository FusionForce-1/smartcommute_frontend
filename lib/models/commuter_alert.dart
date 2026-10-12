// lib/models/commuter_alert.dart
//
// One transit alert in the commuter's feed (GET /alerts/feed, or the public
// GET /alerts for guests), mirroring the backend AlertFeedItem.

import 'vehicle_live_update.dart' show parseServerTime;

enum AlertSeverity {
  critical,
  warning,
  info;

  static AlertSeverity parse(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => AlertSeverity.info);
}

class CommuterAlert {
  const CommuterAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    this.routeCode,
    this.companyName,
    this.isResolved = false,
    this.resolvedAt,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime createdAt;

  /// Null when the alert covers all of an operator's routes.
  final String? routeCode;
  final String? companyName;
  final bool isResolved;
  final DateTime? resolvedAt;
  final bool isRead;

  factory CommuterAlert.fromJson(Map<String, dynamic> json) {
    return CommuterAlert(
      id: json['id'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      severity: AlertSeverity.parse(json['severity'] as String?),
      createdAt: parseServerTime(json['created_at']) ?? DateTime.now().toUtc(),
      routeCode: json['route_code'] as String?,
      companyName: json['company_name'] as String?,
      isResolved: json['is_resolved'] as bool? ?? false,
      resolvedAt: parseServerTime(json['resolved_at']),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  CommuterAlert markedRead() => CommuterAlert(
        id: id,
        title: title,
        message: message,
        severity: severity,
        createdAt: createdAt,
        routeCode: routeCode,
        companyName: companyName,
        isResolved: isResolved,
        resolvedAt: resolvedAt,
        isRead: true,
      );
}

/// The filter chips on the Notifications screen.
enum AlertFilter {
  all('All'),
  critical('Critical'),
  warning('Warning'),
  info('Info'),
  resolved('Resolved');

  const AlertFilter(this.label);

  final String label;

  /// Severity filters show only alerts that are still active.
  bool matches(CommuterAlert alert) => switch (this) {
        AlertFilter.all => true,
        AlertFilter.resolved => alert.isResolved,
        AlertFilter.critical => !alert.isResolved && alert.severity == AlertSeverity.critical,
        AlertFilter.warning => !alert.isResolved && alert.severity == AlertSeverity.warning,
        AlertFilter.info => !alert.isResolved && alert.severity == AlertSeverity.info,
      };
}
