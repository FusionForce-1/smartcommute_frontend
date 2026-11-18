// Selected trip
import 'transport_model.dart';
import 'trip_plan.dart';

/// Selected trip
class SelectedTrip {
  /// Create selected trip
  const SelectedTrip({
    required this.option,
    required this.from,
    required this.to,
    required this.routesById,
  });

  final RouteOption option;

  final String from;
  final String to;

  final Map<String, TransportRoute> routesById;

  String get boardToAlight =>
      'Board at ${option.legs.first.boardLabel} → Alight at ${option.legs.last.alightLabel}';
}

typedef TripSelected = void Function(SelectedTrip trip);
