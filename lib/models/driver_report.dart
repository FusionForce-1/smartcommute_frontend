// lib/models/driver_report.dart
//
// What a driver sends their operator (POST /driver-reports) and their list
// of sent reports (GET /driver-reports/sent, filtered by [ReportsPeriod]).
// The backend always delivers to the driver's own operator and attaches
// the shift's vehicle, route and location itself.

import 'vehicle_live_update.dart' show parseServerTime;

enum DriverReportCategory {
  emergency('emergency', 'Emergency'),
  breakdown('breakdown', 'Breakdown'),
  delay('delay', 'Delay / Heavy traffic'),
  vehicleIssue('vehicle_issue', 'Vehicle issue'),
  other('other', 'Other');

  const DriverReportCategory(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// "Other" says nothing on its own, so it needs a note.
  bool get needsNote => this == other;

  static DriverReportCategory parse(String? value) =>
      values.firstWhere((c) => c.apiValue == value, orElse: () => other);
}

/// Longest note the backend accepts.
const int reportNoteMaxLength = 500;

/// The shift details the backend attached, if the driver was on shift.
class ReportContext {
  const ReportContext({required this.plateNumber, this.routeCode, this.hasLocation = false});

  final String plateNumber;
  final String? routeCode;
  final bool hasLocation;

  factory ReportContext.fromJson(Map<String, dynamic> json) => ReportContext(
        plateNumber: json['plate_number'] as String? ?? '',
        routeCode: json['route_code'] as String?,
        hasLocation: json['lat'] != null && json['lng'] != null,
      );
}

class DriverReport {
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

  factory DriverReport.fromJson(Map<String, dynamic> json) => DriverReport(
        id: json['id'] as String,
        category: DriverReportCategory.parse(json['category'] as String?),
        note: json['note'] as String?,
        context: json['context'] == null ? null : ReportContext.fromJson(json['context'] as Map<String, dynamic>),
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
      );
}

/// The Reports tab's filter chips (and the calendar's [day]).
enum ReportsPeriod {
  recent('Recent'),
  today('Today'),
  yesterday('Yesterday'),
  lastMonth('Last Month'),
  lastYear('Last Year'),
  day('Day');

  const ReportsPeriod(this.label);

  final String label;
}

/// The [since, until) a period covers, in local time; nulls mean open-ended.
/// "Last Month" / "Last Year" are the past 30 / 365 days up to now.
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
