// lib/models/selected_trip.dart
//
// The route the commuter picked with "Select this route": shown on the Home
// map until they cancel it. Held by the dashboard, so it survives tab changes.

import 'transport_model.dart';
import 'trip_plan.dart';

class SelectedTrip {
  const SelectedTrip({
    required this.option,
    required this.from,
    required this.to,
    required this.routesById,
  });

  final RouteOption option;

  /// "Your location" / "Pinned spot · near …" — the trip's ends as planned.
  final String from;
  final String to;

  /// Route lines for legs the recommender sent without their own path.
  final Map<String, TransportRoute> routesById;

  /// "Board at P. Abella → Alight at Jollibee Banawa".
  String get boardToAlight =>
      'Board at ${option.legs.first.boardLabel} → Alight at ${option.legs.last.alightLabel}';
}

typedef TripSelected = void Function(SelectedTrip trip);
