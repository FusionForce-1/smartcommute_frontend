// Driver report
import 'vehicle_live_update.dart' show parseServerTime;

/// Driver report category
enum DriverReportCategory {
  emergency('emergency', 'Emergency'),
  breakdown('breakdown', 'Breakdown'),
  delay('delay', 'Delay / Heavy traffic'),
  vehicleIssue('vehicle_issue', 'Vehicle issue'),
  other('other', 'Other');

  /// Create driver report category
  const DriverReportCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  bool get needsNote => this == other;

  /// Parse driver report
  static DriverReportCategory parse(String? value) =>
      values.firstWhere((c) => c.apiValue == value, orElse: () => other);
}

const int reportNoteMaxLength = 500;

/// Report context
class ReportContext {
  /// Create report context
  const ReportContext({required this.plateNumber, this.routeCode, this.hasLocation = false});

  final String plateNumber;
  final String? routeCode;
  final bool hasLocation;

  /// Parse from JSON
  factory ReportContext.fromJson(Map<String, dynamic> json) => ReportContext(
        plateNumber: json['plate_number'] as String? ?? '',
        routeCode: json['route_code'] as String?,
        hasLocation: json['lat'] != null && json['lng'] != null,
      );
}

/// Driver report
class DriverReport {
  /// Create driver report
  const DriverReport({
    required this.id,
    required this.category,
    required this.createdAt,
    this.note,
    this.context,
  });

  final String id;
  final DriverReportCategory category;
  final String? note;
  final ReportContext? context;
  final DateTime createdAt;

  /// Parse from JSON
  factory DriverReport.fromJson(Map<String, dynamic> json) => DriverReport(
        id: json['id'] as String,
        category: DriverReportCategory.parse(json['category'] as String?),
        note: json['note'] as String?,
        context: json['context'] == null ? null : ReportContext.fromJson(json['context'] as Map<String, dynamic>),
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
      );
}

/// Reports period options
enum ReportsPeriod {
  recent('Recent'),
  today('Today'),
  yesterday('Yesterday'),
  lastMonth('Last Month'),
  lastYear('Last Year'),
  day('Day');

  /// Create reports period
  const ReportsPeriod(this.label);

  final String label;
}

({DateTime? since, DateTime? until}) reportsRange(ReportsPeriod period, DateTime now, {DateTime? day}) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    ReportsPeriod.recent => (since: null, until: null),
    ReportsPeriod.today => (since: today, until: null),
    ReportsPeriod.yesterday => (since: today.subtract(const Duration(days: 1)), until: today),
    ReportsPeriod.lastMonth => (since: today.subtract(const Duration(days: 30)), until: null),
    ReportsPeriod.lastYear => (since: today.subtract(const Duration(days: 365)), until: null),
    ReportsPeriod.day => () {
        final d = day ?? today;
        final start = DateTime(d.year, d.month, d.day);
        return (since: start, until: DateTime(start.year, start.month, start.day + 1));
      }(),
  };
}
