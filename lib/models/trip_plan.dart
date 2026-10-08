// lib/models/trip_plan.dart
//
// Mirror sa backend trip_models.py (POST /trip-plan).
// Walay fare computation diri — gi-display ra nato unsa ang i-return sa backend.

import 'models.dart';

/// Unsa ang i-minimize sa trip planner (backend `preferences.minimize`).
enum TripPreference {
  time('time', 'Fastest'),
  fare('fare', 'Cheapest'),
  transfers('transfers', 'Fewest transfers');

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
  });

  final int rank;
  final List<RouteLeg> legs;
  final int totalEtaMin;
  final double totalFare;
  final int transfers;

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
  });

  final String routeId;
  final String routeName;
  final StopModel boardStop;
  final StopModel alightStop;
  final int etaMin;
  final double fare;

  String get boardLabel => boardStop.displayName;

  /// Ang backend stub mo-return og placeholder para sa alight stop usab
  /// (parehas sa board) — dili "Your location" kay sayop man.
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
    );
  }
}

extension StopDisplay on StopModel {
  /// Ang backend stub mo-return og "Origin" stop nga id "0" sa [0, 0]
  /// kung walay tinuod nga stop — ipakita nato as "Your location".
  bool get isPlaceholder => id == '0' || (location.lat == 0 && location.lng == 0);

  String get displayName => isPlaceholder ? 'Your location' : name;
}

String formatFare(double fare) => '₱${fare.toStringAsFixed(2)}';

String formatTransfers(int transfers) {
  if (transfers == 0) return 'No transfers';
  if (transfers == 1) return '1 transfer';
  return '$transfers transfers';
}
