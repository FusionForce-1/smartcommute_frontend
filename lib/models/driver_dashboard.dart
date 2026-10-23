// lib/models/driver_dashboard.dart
//
// The signed-in driver's dashboard (GET /drivers/me), their open shift
// and the summary returned when a shift ends.

import 'vehicle_live_update.dart' show parseServerTime;

/// What the driver tells commuters about their trip.
enum DutyStatus {
  onRoute('on_route', 'On-Route'),
  delayed('delayed', 'Delayed'),
  unavailable('unavailable', 'Unavailable');

  const DutyStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static DutyStatus fromApi(String? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => unavailable);
}

/// How much of a shift the driver's location was being shared.
enum GpsCoverage {
  full('Active throughout shift'),
  partial('Shared for part of the shift'),
  none('Not shared');

  const GpsCoverage(this.label);

  final String label;

  static GpsCoverage fromApi(String? value) =>
      values.firstWhere((c) => c.name == value, orElse: () => none);
}

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
  });

  final String id;
  final String plateNumber;
  final String routeId;
  final String? routeCode;
  final String? routeName;
  final String? terminalA;
  final String? terminalB;

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
      );
}

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

class DriverDashboardData {
  const DriverDashboardData({
    required this.name,
    required this.dutyStatus,
    required this.vehicles,
    this.driverCode,
    this.shift,
  });

  final String name;
  final String? driverCode;
  final DutyStatus dutyStatus;
  final List<AssignedVehicle> vehicles;
  final DriverShift? shift;

  factory DriverDashboardData.fromJson(Map<String, dynamic> json) => DriverDashboardData(
        name: json['name'] as String,
        driverCode: json['driver_code'] as String?,
        dutyStatus: DutyStatus.fromApi(json['duty_status'] as String?),
        vehicles: [
          for (final v in json['vehicles'] as List) AssignedVehicle.fromJson(v as Map<String, dynamic>),
        ],
        shift: json['shift'] == null ? null : DriverShift.fromJson(json['shift'] as Map<String, dynamic>),
      );
}

class ShiftSummary {
  const ShiftSummary({
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.distanceKm,
    required this.trips,
    required this.passengers,
    required this.avgCrowdPercent,
    required this.gpsCoverage,
    required this.vehicle,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final double distanceKm;
  final int trips;
  final int passengers;
  final int avgCrowdPercent;
  final GpsCoverage gpsCoverage;
  final AssignedVehicle vehicle;

  factory ShiftSummary.fromJson(Map<String, dynamic> json) => ShiftSummary(
        startedAt: parseServerTime(json['started_at'])!,
        endedAt: parseServerTime(json['ended_at'])!,
        duration: Duration(seconds: (json['duration_seconds'] as num).toInt()),
        distanceKm: (json['distance_km'] as num).toDouble(),
        trips: (json['trips'] as num).toInt(),
        passengers: (json['passengers'] as num).toInt(),
        avgCrowdPercent: (json['avg_crowd_percent'] as num).toInt(),
        gpsCoverage: GpsCoverage.fromApi(json['gps_coverage'] as String?),
        vehicle: AssignedVehicle.fromJson(json['vehicle'] as Map<String, dynamic>),
      );
}
