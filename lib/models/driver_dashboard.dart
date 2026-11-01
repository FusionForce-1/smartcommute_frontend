// lib/models/driver_dashboard.dart
//
// The signed-in driver's dashboard (GET /drivers/me): their assigned
// vehicles and routes, the shift their operator started, their route
// status, who they drive for, their most recent route, and their updates
// (GET /notifications, filtered by [UpdatesPeriod]).

import 'vehicle_live_update.dart' show parseServerTime;

/// A vehicle the operator assigned to this driver, with its route.
class AssignedVehicle {
  const AssignedVehicle({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    this.routeCode,
    this.routeName,
    this.terminalA,
    this.terminalB,
    this.hasTracker = false,
  });

  final String id;
  final String plateNumber;
  final String routeId;
  final String? routeCode;
  final String? routeName;
  final String? terminalA;
  final String? terminalB;

  /// A GPS tracker is paired. The phone only backs one up: without it the
  /// backend refuses the phone's GPS.
  final bool hasTracker;

  /// "Talamban → Pier 1 Terminal", falling back to the route's name.
  String get routeLine {
    if (terminalA != null && terminalB != null) return '$terminalA → $terminalB';
    return routeName ?? 'Route details unavailable';
  }

  factory AssignedVehicle.fromJson(Map<String, dynamic> json) => AssignedVehicle(
        id: json['id'] as String,
        plateNumber: json['plate_number'] as String,
        routeId: json['route_id'] as String? ?? '',
        routeCode: json['route_code'] as String?,
        routeName: json['route_name'] as String?,
        terminalA: json['terminal_a'] as String?,
        terminalB: json['terminal_b'] as String?,
        hasTracker: json['has_tracker'] as bool? ?? false,
      );
}

/// The shift the operator started; the driver reports crowd and passengers on it.
class DriverShift {
  const DriverShift({
    required this.id,
    required this.vehicleId,
    required this.startedAt,
    this.crowdPercent = 0,
    this.passengers = 0,
    this.distanceKm = 0,
  });

  final String id;
  final String vehicleId;
  final DateTime startedAt;
  final int crowdPercent;
  final int passengers;

  /// Driven so far, from the GPS fixes the server had when this was loaded.
  final double distanceKm;

  DriverShift copyWith({int? crowdPercent, int? passengers}) => DriverShift(
        id: id,
        vehicleId: vehicleId,
        startedAt: startedAt,
        crowdPercent: crowdPercent ?? this.crowdPercent,
        passengers: passengers ?? this.passengers,
        distanceKm: distanceKm,
      );

  factory DriverShift.fromJson(Map<String, dynamic> json) => DriverShift(
        id: json['id'] as String,
        vehicleId: json['vehicle_id'] as String,
        startedAt: parseServerTime(json['started_at'])!,
        crowdPercent: (json['crowd_percent'] as num?)?.toInt() ?? 0,
        passengers: (json['passengers'] as num?)?.toInt() ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      );
}

/// The driver's Route Status during a shift; commuters see it on the map.
enum RouteStatus {
  onRoute('on_route', 'On-Route'),
  delayed('delayed', 'Delayed'),
  unavailable('unavailable', 'Unavailable');

  const RouteStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static RouteStatus fromApi(String? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => RouteStatus.unavailable);
}

/// Who the driver drives for.
class DriverOperator {
  const DriverOperator({this.companyName, this.ownerName});

  final String? companyName;
  final String? ownerName;

  factory DriverOperator.fromJson(Map<String, dynamic> json) => DriverOperator(
        companyName: json['company_name'] as String?,
        ownerName: json['owner_name'] as String?,
      );
}

class DriverDashboardData {
  const DriverDashboardData({
    required this.name,
    required this.vehicles,
    this.driverCode,
    this.email,
    this.shift,
    this.routeStatus = RouteStatus.unavailable,
    this.operator,
    this.recentRoute,
  });

  final String name;
  final String? driverCode;
  final String? email;
  final List<AssignedVehicle> vehicles;
  final DriverShift? shift;
  final RouteStatus routeStatus;
  final DriverOperator? operator;

  /// The vehicle and route of the driver's last ended shift.
  final AssignedVehicle? recentRoute;

  factory DriverDashboardData.fromJson(Map<String, dynamic> json) => DriverDashboardData(
        name: json['name'] as String,
        driverCode: json['driver_code'] as String?,
        email: json['email'] as String?,
        vehicles: [
          for (final v in json['vehicles'] as List) AssignedVehicle.fromJson(v as Map<String, dynamic>),
        ],
        shift: json['shift'] == null ? null : DriverShift.fromJson(json['shift'] as Map<String, dynamic>),
        routeStatus: RouteStatus.fromApi(json['duty_status'] as String?),
        operator: json['operator'] == null ? null : DriverOperator.fromJson(json['operator'] as Map<String, dynamic>),
        recentRoute: json['recent_route'] == null
            ? null
            : AssignedVehicle.fromJson(json['recent_route'] as Map<String, dynamic>),
      );
}

/// The Updates tab's filter chips (and the calendar's [day]).
enum UpdatesPeriod {
  recent('Recent'),
  today('Today'),
  yesterday('Yesterday'),
  lastMonth('Last Month'),
  lastYear('Last Year'),
  day('Day');

  const UpdatesPeriod(this.label);

  final String label;
}

/// The [since, until) a period covers, in local time; nulls mean open-ended.
/// "Last Month" / "Last Year" are the past 30 / 365 days up to now.
({DateTime? since, DateTime? until}) updatesRange(UpdatesPeriod period, DateTime now, {DateTime? day}) {
  final today = DateTime(now.year, now.month, now.day);
  return switch (period) {
    UpdatesPeriod.recent => (since: null, until: null),
    UpdatesPeriod.today => (since: today, until: null),
    UpdatesPeriod.yesterday => (since: today.subtract(const Duration(days: 1)), until: today),
    UpdatesPeriod.lastMonth => (since: today.subtract(const Duration(days: 30)), until: null),
    UpdatesPeriod.lastYear => (since: today.subtract(const Duration(days: 365)), until: null),
    UpdatesPeriod.day => () {
        final d = day ?? today;
        final start = DateTime(d.year, d.month, d.day);
        return (since: start, until: DateTime(start.year, start.month, start.day + 1));
      }(),
  };
}

/// One of the driver's notifications: shift started / ended, a vehicle
/// assigned, an operator announcement, ...
class DriverUpdate {
  const DriverUpdate({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    this.isRead = false,
  });

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  factory DriverUpdate.fromJson(Map<String, dynamic> json) => DriverUpdate(
        id: json['id'] as String,
        kind: json['kind'] as String? ?? '',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
        isRead: json['is_read'] as bool? ?? false,
      );
}
