// lib/services/boarding_planner.dart
//
// "How do I catch this jeep?" for a vehicle picked from Nearby Vehicles.
// The commuter boards where the jeep's route passes closest to them, not
// where the jeep happens to be now: that's the shortest walk, and the jeep
// comes to them. Pure geometry on the route line; no network.
//
// Distances use a flat-earth (equirectangular) projection around the
// points, accurate to well under 1% over the few km a walk or a jeep
// approach covers.

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Average adult step on a city sidewalk.
const double metresPerStep = 0.75;

/// Walking pace used when no walking route time is known (≈ 4.7 km/h).
const double walkMetresPerSecond = 1.3;

/// A point on the route line: where it is and how far along the line.
class RoutePosition {
  const RoutePosition({required this.point, required this.alongM, required this.offsetM, required this.segment});

  final LatLng point;

  /// Metres from the start of the line.
  final double alongM;

  /// Metres between the original point and the line.
  final double offsetM;

  /// Index of the segment [segment, segment + 1] the point lies on.
  final int segment;
}

class BoardingPlan {
  const BoardingPlan({
    required this.boardAt,
    required this.walkStraightM,
    required this.onRoute,
    this.jeepToBoardM,
    this.jeepPath = const [],
  });

  /// Where to wait for the jeep.
  final LatLng boardAt;

  /// Straight-line distance from the commuter to [boardAt].
  final double walkStraightM;

  /// False when the route has no line: then [boardAt] is the jeep itself.
  final bool onRoute;

  /// How far the jeep still drives along its route to reach [boardAt];
  /// null when it has already passed it (or there's no route line).
  final double? jeepToBoardM;

  /// The stretch of route from the jeep to [boardAt], for the map.
  final List<LatLng> jeepPath;

  bool get jeepPassed => onRoute && jeepToBoardM == null;
}

double _mPerDegLat() => 111320.0;
double _mPerDegLng(double lat) => 111320.0 * math.cos(lat * math.pi / 180);

/// Projects [p] onto [line]; null if the line has fewer than 2 points.
RoutePosition? projectOnLine(List<LatLng> line, LatLng p) {
  if (line.length < 2) return null;
  final kx = _mPerDegLng(p.latitude), ky = _mPerDegLat();
  double x(LatLng q) => (q.longitude - p.longitude) * kx;
  double y(LatLng q) => (q.latitude - p.latitude) * ky;

  RoutePosition? best;
  var along = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final ax = x(line[i]), ay = y(line[i]), bx = x(line[i + 1]), by = y(line[i + 1]);
    final dx = bx - ax, dy = by - ay;
    final len2 = dx * dx + dy * dy;
    final t = len2 == 0 ? 0.0 : (((0 - ax) * dx + (0 - ay) * dy) / len2).clamp(0.0, 1.0);
    final px = ax + t * dx, py = ay + t * dy;
    final offset = math.sqrt(px * px + py * py);
    final segLen = math.sqrt(len2);
    if (best == null || offset < best.offsetM) {
      best = RoutePosition(
        point: LatLng(p.latitude + py / ky, p.longitude + px / kx),
        alongM: along + t * segLen,
        offsetM: offset,
        segment: i,
      );
    }
    along += segLen;
  }
  return best;
}

/// The part of [line] between two positions on it (from -> to, to after from).
List<LatLng> sliceLine(List<LatLng> line, RoutePosition from, RoutePosition to) {
  return [from.point, for (var i = from.segment + 1; i <= to.segment; i++) line[i], to.point];
}

/// Where to board [route] (its line) to catch the jeep at [jeep], walking from [user].
BoardingPlan planBoarding({required List<LatLng> route, required LatLng user, required LatLng jeep}) {
  const distance = Distance();
  final you = projectOnLine(route, user);
  final bus = projectOnLine(route, jeep);
  if (you == null || bus == null) {
    // No route line: walk to the jeep itself.
    return BoardingPlan(boardAt: jeep, walkStraightM: distance.as(LengthUnit.Meter, user, jeep), onRoute: false);
  }
  final ahead = bus.alongM <= you.alongM;
  return BoardingPlan(
    boardAt: you.point,
    walkStraightM: you.offsetM,
    onRoute: true,
    jeepToBoardM: ahead ? you.alongM - bus.alongM : null,
    jeepPath: ahead ? sliceLine(route, bus, you) : const [],
  );
}

/// About how many steps a walk of [metres] takes.
int stepsFor(double metres) => (metres / metresPerStep).round();

/// Minutes for the jeep to cover [metres] at [speedKmh] (slow/unknown -> 15 km/h city pace).
int jeepMinutes(double metres, double? speedKmh) {
  final kmh = (speedKmh == null || speedKmh < 5) ? 15.0 : speedKmh;
  return math.max(1, (metres / 1000 / kmh * 60).round());
}
