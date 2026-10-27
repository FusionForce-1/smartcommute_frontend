// lib/models/trip_plan.dart
//
// Mirror sa backend trip_models.py (POST /trip-plan).
// Walay fare computation diri — gi-display ra nato unsa ang i-return sa backend.

import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'transport_model.dart';
import 'vehicle_live_update.dart' show parseServerTime;

/// Unsa ang i-minimize sa trip planner (backend `preferences.minimize`).
enum TripPreference {
  time('time', 'Fastest'),
  fare('fare', 'Cheapest'),
  transfers('transfers', 'Few Transfers');

  const TripPreference(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

class TripPlanResponse {
  const TripPlanResponse({required this.options, required this.generatedAt});

  final List<RouteOption> options;
  final DateTime generatedAt;

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    return TripPlanResponse(
      options: (json['options'] as List<dynamic>)
          .map((option) => RouteOption.fromJson(option as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }
}

class RouteOption {
  const RouteOption({
    required this.rank,
    required this.legs,
    required this.totalEtaMin,
    required this.totalFare,
    required this.transfers,
    this.totalWalkM,
    this.walkFromAlightM,
    this.walkFromAlightMin,
    this.arriveAt,
  });

  final int rank;
  final List<RouteLeg> legs;
  final int totalEtaMin;
  final double totalFare;
  final int transfers;

  /// Walking for the whole trip, and the last stretch (stop -> destination).
  /// Null from older backends that didn't send them.
  final int? totalWalkM;
  final int? walkFromAlightM;
  final int? walkFromAlightMin;

  /// Estimated arrival at the destination (UTC), traffic included.
  final DateTime? arriveAt;

  /// Same routes in the same order — used to keep the commuter's selection
  /// when the plan refreshes as they move.
  String get signature => legs.map((leg) => leg.routeId).join('>');

  /// E.g. "01K → 13C"
  String get routeSummary => legs.map((leg) => leg.routeName).join(' → ');

  factory RouteOption.fromJson(Map<String, dynamic> json) {
    return RouteOption(
      rank: json['rank'] as int,
      legs: (json['legs'] as List<dynamic>)
          .map((leg) => RouteLeg.fromJson(leg as Map<String, dynamic>))
          .toList(),
      totalEtaMin: json['total_eta_min'] as int,
      totalFare: (json['total_fare'] as num).toDouble(),
      transfers: json['transfers'] as int,
      totalWalkM: json['total_walk_m'] as int?,
      walkFromAlightM: json['walk_from_alight_m'] as int?,
      walkFromAlightMin: json['walk_from_alight_min'] as int?,
      arriveAt: parseServerTime(json['arrive_at']),
    );
  }
}

class RouteLeg {
  const RouteLeg({
    required this.routeId,
    required this.routeName,
    required this.boardStop,
    required this.alightStop,
    required this.etaMin,
    required this.fare,
    this.routeCode,
    this.walkToBoardM,
    this.walkToBoardMin,
    this.waitMin,
    this.waitIsLive = false,
    this.nextVehicleId,
    this.rideKm,
    this.rideMin,
    this.path,
    this.traffic,
    this.speedKmh,
    this.speedIsLive = false,
    this.trafficDelayMin,
    this.congestionReported = false,
    this.direction = 'outbound',
  });

  final String routeId;
  final String routeName;
  final StopModel boardStop;
  final StopModel alightStop;
  final int etaMin;
  final double fare;

  // From the route recommender; null from older backends.
  final String? routeCode;
  final int? walkToBoardM;
  final int? walkToBoardMin;

  /// Minutes until the next jeep reaches [boardStop] after the commuter does.
  final int? waitMin;

  /// True when [waitMin] comes from a live jeep's GPS, false for a typical wait.
  final bool waitIsLive;
  final String? nextVehicleId;
  final double? rideKm;
  final int? rideMin;

  /// The ridden part of the route (board -> alight), along the streets.
  final List<LatLng>? path;

  /// "light" | "moderate" | "heavy" — from the jeeps' live speed when
  /// [speedIsLive], else the usual traffic for this time of day.
  final String? traffic;
  final double? speedKmh;
  final bool speedIsLive;

  /// Extra minutes this ride takes compared with free-flowing traffic.
  final int? trafficDelayMin;

  /// A driver or operator marked the route congested.
  final bool congestionReported;

  /// "outbound" (Terminal A -> B, the way the route is drawn) or "return" (B -> A).
  final String direction;

  bool get isReturn => direction == 'return';

  String get boardLabel => boardStop.displayName;

  /// A placeholder alight stop (no stop near the destination) reads as the destination.
  String get alightLabel =>
      alightStop.isPlaceholder ? 'Your destination' : alightStop.name;

  factory RouteLeg.fromJson(Map<String, dynamic> json) {
    return RouteLeg(
      routeId: json['route_id'] as String,
      routeName: json['route_name'] as String,
      boardStop: StopModel.fromJson(json['board_stop'] as Map<String, dynamic>),
      alightStop: StopModel.fromJson(json['alight_stop'] as Map<String, dynamic>),
      etaMin: json['eta_min'] as int,
      fare: (json['fare'] as num).toDouble(),
      routeCode: json['route_code'] as String?,
      walkToBoardM: json['walk_to_board_m'] as int?,
      walkToBoardMin: json['walk_to_board_min'] as int?,
      waitMin: json['wait_min'] as int?,
      waitIsLive: json['wait_is_live'] as bool? ?? false,
      nextVehicleId: json['next_vehicle_id'] as String?,
      rideKm: (json['ride_km'] as num?)?.toDouble(),
      rideMin: json['ride_min'] as int?,
      path: _parseLine(json['path']),
      traffic: json['traffic'] as String?,
      speedKmh: (json['speed_kmh'] as num?)?.toDouble(),
      speedIsLive: json['speed_source'] == 'live',
      trafficDelayMin: json['traffic_delay_min'] as int?,
      congestionReported: json['congestion_reported'] as bool? ?? false,
      direction: json['direction'] as String? ?? 'outbound',
    );
  }

  static List<LatLng>? _parseLine(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final coords = json['coordinates'] as List<dynamic>? ?? const [];
    final points = [
      for (final c in coords)
        LatLng(((c as List<dynamic>)[1] as num).toDouble(), (c[0] as num).toDouble()),
    ];
    return points.length > 1 ? points : null;
  }
}

extension StopDisplay on StopModel {
  /// Ang backend stub mo-return og "Origin" stop nga id "0" sa [0, 0]
  /// kung walay tinuod nga stop — ipakita nato as "Your location".
  bool get isPlaceholder => id == '0' || (location.lat == 0 && location.lng == 0);

  String get displayName => isPlaceholder ? 'Your location' : name;
}

extension RouteOptionStops on RouteOption {
  /// Stops ridden across every leg, counted along each route's stop order.
  /// Null when a leg's route or its board/alight stop isn't in [routesById]
  /// (e.g. the backend's placeholder origin stop).
  int? stopCount(Map<String, TransportRoute> routesById) {
    var total = 0;
    for (final leg in legs) {
      final stops = routesById[leg.routeId]?.stops;
      if (stops == null) return null;
      final ordered = [...stops]..sort((a, b) => a.sequence.compareTo(b.sequence));
      final board = ordered.indexWhere((s) => s.id == leg.boardStop.id);
      final alight = ordered.indexWhere((s) => s.id == leg.alightStop.id);
      if (board < 0 || alight < 0) return null;
      total += (alight - board).abs();
    }
    return total;
  }
}

/// A named point the commuter travels from or to (a stop, or a map pin).
class TripPlace {
  const TripPlace({required this.location, required this.label});

  final LatLng location;
  final String label;
}

String formatFare(double fare) => '₱${fare.toStringAsFixed(2)}';

/// "₱13" for whole pesos, "₱13.50" otherwise — for compact fare badges.
String formatFareCompact(double fare) =>
    fare == fare.roundToDouble() ? '₱${fare.toStringAsFixed(0)}' : formatFare(fare);

/// "Walk 104 m to Capitol · Next PUV 4 min (live)" — null if the backend
/// didn't send walking/wait details.
String? boardingSummary(RouteLeg leg) {
  final walk = leg.walkToBoardM;
  final wait = leg.waitMin;
  if (walk == null && wait == null) return null;
  final parts = <String>[
    if (walk != null) walk < 15 ? 'At ${leg.boardLabel}' : 'Walk ${formatDistance(walk)} to ${leg.boardLabel}',
    if (wait != null)
      leg.waitIsLive
          ? (wait == 0 ? 'PUV arriving now (live)' : 'Next PUV $wait min (live)')
          : '~$wait min wait',
  ];
  return parts.join('  •  ');
}

/// "Heavy traffic (+6 min)  •  Congestion reported" — null without traffic data.
String? trafficSummary(RouteOption option) {
  final legs = option.legs.where((l) => l.traffic != null).toList();
  if (legs.isEmpty) return null;
  const order = ['light', 'moderate', 'heavy'];
  final worst = legs.map((l) => l.traffic!).reduce(
      (a, b) => order.indexOf(a) >= order.indexOf(b) ? a : b);
  final delay = legs.fold<int>(0, (sum, l) => sum + (l.trafficDelayMin ?? 0));
  final label = '${worst[0].toUpperCase()}${worst.substring(1)} traffic';
  return [
    delay > 0 ? '$label (+$delay min)' : label,
    if (legs.any((l) => l.congestionReported)) 'Congestion reported',
  ].join('  •  ');
}

String formatDistance(int metres) =>
    metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';

String formatTransfers(int transfers) {
  if (transfers == 0) return 'No transfers';
  if (transfers == 1) return '1 transfer';
  return '$transfers transfers';
}
