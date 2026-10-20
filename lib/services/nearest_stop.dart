// lib/services/nearest_stop.dart
//
// The stop closest to a point, used to describe places in words
// ("near Fuente Osmeña") on the Route tab and the Pick on map screen.

import 'package:latlong2/latlong.dart';

import '../models/transport_stop.dart';

/// Within this distance a point is described by its nearest stop.
const double nearStopMeters = 600;

/// The nearest stop to [point] within [within] metres, or null.
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

/// "120 m" / "1.4 km".
String formatMetres(double metres) =>
    metres < 1000 ? '${metres.round()} m' : '${(metres / 1000).toStringAsFixed(1)} km';
