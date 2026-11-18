// Trip plan
import 'package:latlong2/latlong.dart';

import 'models.dart';
import 'transport_model.dart';
import 'vehicle_live_update.dart' show parseServerTime;

/// Trip preference options
enum TripPreference {
  time('time', 'Fastest'),
  transfers('transfers', 'Few Transfers');

  /// Create trip preference
  const TripPreference(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

/// Trip plan response
class TripPlanResponse {
  /// Create trip plan response
  const TripPlanResponse({required this.options, required this.generatedAt});

  final List<RouteOption> options;
  final DateTime generatedAt;

  /// Parse from JSON
  factory TripPlanResponse.fromJson(Map<String, dynamic> json) {
    return TripPlanResponse(
      options: (json['options'] as List<dynamic>)
          .map((option) => RouteOption.fromJson(option as Map<String, dynamic>))
          .toList(),
      generatedAt: DateTime.parse(json['generated_at'] as String),
    );
  }
}

/// Route option
class RouteOption {
  /// Create route option
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

  final int? totalWalkM;
  final int? walkFromAlightM;
  final int? walkFromAlightMin;

  final DateTime? arriveAt;

  String get signature => legs.map((leg) => leg.routeId).join('>');

  String get routeSummary => legs.map((leg) => leg.routeName).join(' → ');

  /// Parse from JSON
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

/// Route leg
class RouteLeg {
  /// Create route leg
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

  final String? routeCode;
  final int? walkToBoardM;
  final int? walkToBoardMin;

  final int? waitMin;

  final bool waitIsLive;
  final String? nextVehicleId;
  final double? rideKm;
  final int? rideMin;

  final List<LatLng>? path;

  final String? traffic;
  final double? speedKmh;
  final bool speedIsLive;

  final int? trafficDelayMin;

  final bool congestionReported;

  final String direction;

  bool get isReturn => direction == 'return';

  String get boardLabel => boardStop.displayName;

  String get alightLabel =>
      alightStop.isPlaceholder ? 'Your destination' : alightStop.name;

  /// Parse from JSON
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

  /// Parse line
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

/// Stop display extension
extension StopDisplay on StopModel {
  bool get isPlaceholder => id == '0' || (location.lat == 0 && location.lng == 0);

  String get displayName => isPlaceholder ? 'Your location' : name;
}

/// Route option stops extension
extension RouteOptionStops on RouteOption {
  /// Stop count
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

/// Trip place
class TripPlace {
  /// Create trip place
  const TripPlace({required this.location, required this.label});

  final LatLng location;
  final String label;
}

/// Format fare
String formatFare(double fare) => '₱${fare.toStringAsFixed(2)}';

/// Format fare compact
String formatFareCompact(double fare) =>
    fare == fare.roundToDouble() ? '₱${fare.toStringAsFixed(0)}' : formatFare(fare);

/// Boarding summary
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

/// Traffic summary
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

/// Format distance
String formatDistance(int metres) =>
    metres < 1000 ? '$metres m' : '${(metres / 1000).toStringAsFixed(1)} km';

/// Format transfers
String formatTransfers(int transfers) {
  if (transfers == 0) return 'No transfers';
  if (transfers == 1) return '1 transfer';
  return '$transfers transfers';
}
