// Nearest stop
import 'package:latlong2/latlong.dart';

import '../models/transport_stop.dart';

const double nearStopMeters = 600;

({TransportStop stop, double metres})? nearestStop(
  List<TransportStop> stops,
  LatLng point, {
  double within = nearStopMeters,
}) {
  TransportStop? best;
  var bestMetres = double.infinity;
  for (final stop in stops) {
    final d = const Distance().as(LengthUnit.Meter, point, stop.location);
    if (d < bestMetres) {
      bestMetres = d;
      best = stop;
    }
  }
  if (best == null || bestMetres > within) return null;
  return (stop: best, metres: bestMetres);
}

/// Format metres
String formatMetres(double metres) =>
    metres < 1000 ? '${metres.round()} m' : '${(metres / 1000).toStringAsFixed(1)} km';
