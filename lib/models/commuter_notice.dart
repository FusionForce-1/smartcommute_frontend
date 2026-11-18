// Commuter notice
import 'vehicle_live_update.dart' show parseServerTime;

/// Notice category
enum NoticeCategory {
  serviceAlert('service_alert', 'Service alert'),
  scheduleChange('schedule_change', 'Schedule change'),
  promotion('promotion', 'Promotion');

  /// Create notice category
  const NoticeCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Parse notice category
  static NoticeCategory parse(String? value) =>
      values.firstWhere((c) => c.apiValue == value, orElse: () => serviceAlert);
}

/// Notice severity options
enum NoticeSeverity {
  critical,
  warning,
  info;

  /// Parse notice severity
  static NoticeSeverity parse(String? value) =>
      values.firstWhere((s) => s.name == value, orElse: () => NoticeSeverity.info);
}

/// Commuter notice
class CommuterNotice {
  /// Create commuter notice
  const CommuterNotice({
    required this.id,
    required this.category,
    required this.title,
    required this.message,
    required this.createdAt,
    this.severity = NoticeSeverity.info,
    this.companyName,
    this.routeCodes = const [],
    this.isRead = false,
  });

  final String id;
  final NoticeCategory category;

  final NoticeSeverity severity;
  final String title;
  final String message;
  final String? companyName;
  final List<String> routeCodes;
  final DateTime createdAt;
  final bool isRead;

  /// Parse from JSON
  factory CommuterNotice.fromJson(Map<String, dynamic> json) => CommuterNotice(
        id: json['id'] as String,
        category: NoticeCategory.parse(json['category'] as String?),
        severity: NoticeSeverity.parse(json['severity'] as String?),
        title: json['title'] as String,
        message: json['message'] as String,
        companyName: json['company_name'] as String?,
        routeCodes: [for (final code in json['route_codes'] as List? ?? const []) code as String],
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now().toUtc(),
        isRead: json['is_read'] as bool? ?? false,
      );

  /// Marked read
  CommuterNotice markedRead() => CommuterNotice(
        id: id,
        category: category,
        severity: severity,
        title: title,
        message: message,
        companyName: companyName,
        routeCodes: routeCodes,
        createdAt: createdAt,
        isRead: true,
      );
}

/// Notice filter options
enum NoticeFilter {
  all('All', null),
  serviceAlerts('Service alerts', NoticeCategory.serviceAlert),
  schedule('Schedule', NoticeCategory.scheduleChange),
  promotions('Promotions', NoticeCategory.promotion);

  /// Create notice filter
  const NoticeFilter(this.label, this.category);

  final String label;
  final NoticeCategory? category;
}
