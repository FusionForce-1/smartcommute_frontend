// Driver dashboard
import 'vehicle_live_update.dart' show parseServerTime;

/// Assigned vehicle
class AssignedVehicle {
  /// Create assigned vehicle
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

  final bool hasTracker;

  String get routeLine {
    if (terminalA != null && terminalB != null) return '$terminalA → $terminalB';
    return routeName ?? 'Route details unavailable';
  }

  /// Parse from JSON
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

/// Driver shift
class DriverShift {
  /// Create driver shift
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

  final double distanceKm;

  /// Copy with changes
  DriverShift copyWith({int? crowdPercent, int? passengers}) => DriverShift(
        id: id,
        vehicleId: vehicleId,
        startedAt: startedAt,
        crowdPercent: crowdPercent ?? this.crowdPercent,
        passengers: passengers ?? this.passengers,
        distanceKm: distanceKm,
      );

  /// Parse from JSON
  factory DriverShift.fromJson(Map<String, dynamic> json) => DriverShift(
        id: json['id'] as String,
        vehicleId: json['vehicle_id'] as String,
        startedAt: parseServerTime(json['started_at'])!,
        crowdPercent: (json['crowd_percent'] as num?)?.toInt() ?? 0,
        passengers: (json['passengers'] as num?)?.toInt() ?? 0,
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
      );
}

/// Route status
enum RouteStatus {
  onRoute('on_route', 'On-Route'),
  delayed('delayed', 'Delayed'),
  unavailable('unavailable', 'Unavailable');

  /// Create route status
  const RouteStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// From API
  static RouteStatus fromApi(String? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => RouteStatus.unavailable);
}

/// Driver operator
class DriverOperator {
  /// Create driver operator
  const DriverOperator({this.companyName, this.ownerName});

  final String? companyName;
  final String? ownerName;

  /// Parse from JSON
  factory DriverOperator.fromJson(Map<String, dynamic> json) => DriverOperator(
        companyName: json['company_name'] as String?,
        ownerName: json['owner_name'] as String?,
      );
}

/// Driver dashboard data
class DriverDashboardData {
  /// Create driver dashboard data
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

  final AssignedVehicle? recentRoute;

  /// Parse from JSON
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
