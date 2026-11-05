// lib/services/boarding_planner.dart
//
// "How do I catch this jeep?" for a vehicle picked from Nearby Vehicles.
// The commuter boards near them, not where the jeep happens to be now: the
// jeep comes to them. That's the route's closest bus stop if it isn't much
// further ([stopExtraWalkM]), else the closest point of the route: the
// shortest walk. Pure geometry on the route line; no network.
//
// Routes run both ways, so [lineAsDriven] first turns the line the way the
// jeep is going: otherwise a jeep on its way back to the commuter would look
// like it had already passed them.
//
// Distances use a flat-earth (equirectangular) projection around the
// points, accurate to well under 1% over the few km a walk or a jeep
// approach covers.

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/transport_model.dart' show RouteStop;

/// Average adult step on a city sidewalk.
const double metresPerStep = 0.75;

/// Walking pace used when no walking route time is known (≈ 4.7 km/h).
const double walkMetresPerSecond = 1.3;

/// A stop this close to the route line counts as on it.
const double stopOnLineM = 60;

/// Worth walking this much further than the closest point of the route, to
/// wait at a real stop.
const double stopExtraWalkM = 200;

/// "0.35 km", "1.25 km", "12.4 km".
String formatKm(double metres) {
  final km = metres / 1000;
  return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
}

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
    required this.jeepStraightM,
    required this.onRoute,
    this.stopName,
    this.jeepToBoardM,
    this.jeepPath = const [],
  });

  /// Where to wait for the jeep.
  final LatLng boardAt;

  /// The bus stop at [boardAt]; null when it's just a point of the route.
  final String? stopName;

  /// Straight-line distance from the commuter to [boardAt].
  final double walkStraightM;

  /// Straight-line distance from the commuter to the jeep.
  final double jeepStraightM;

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

/// True when [heading] points more than [limit] degrees away from the way
/// [line] runs at [at].
bool headingAgainstLine(List<LatLng> line, RoutePosition at, double heading, {double limit = 90}) {
  final along = const Distance().bearing(line[at.segment], line[at.segment + 1]);
  return ((heading - along + 540) % 360 - 180).abs() > limit;
}

/// [line] in the direction the jeep at [jeep] is driving it. Without a
/// [heading] (it hasn't moved yet) it's taken to be coming towards [user].
List<LatLng> lineAsDriven(List<LatLng> line, {required LatLng jeep, required LatLng user, double? heading}) {
  final bus = projectOnLine(line, jeep);
  if (bus == null) return line;
  final backwards = heading != null
      ? headingAgainstLine(line, bus, heading)
      : bus.alongM > (projectOnLine(line, user)?.alongM ?? bus.alongM);
  return backwards ? line.reversed.toList() : line;
}

/// The nearest stop on [route] within [stopExtraWalkM] of the closest point
/// [you]; with [jeepAt], only stops it hasn't passed.
({RouteStop stop, RoutePosition position, double walkM})? _stopToBoardAt(
  List<LatLng> route,
  List<RouteStop> stops,
  LatLng user,
  RoutePosition you,
  RoutePosition? jeepAt,
) {
  const distance = Distance(roundResult: false);
  ({RouteStop stop, RoutePosition position, double walkM})? best;
  for (final stop in stops) {
    final walkM = distance.as(LengthUnit.Meter, user, stop.location);
    if (walkM > you.offsetM + stopExtraWalkM || (best != null && walkM >= best.walkM)) continue;
    final position = projectOnLine(route, stop.location);
    if (position == null || position.offsetM > stopOnLineM) continue;
    if (jeepAt != null && position.alongM < jeepAt.alongM) continue;
    best = (stop: stop, position: position, walkM: walkM);
  }
  return best;
}

/// Where to board [route] (its line, in the jeep's direction) to catch the
/// jeep at [jeep], walking from [user].
BoardingPlan planBoarding({
  required List<LatLng> route,
  required LatLng user,
  required LatLng jeep,
  List<RouteStop> stops = const [],
}) {
  final jeepM = const Distance(roundResult: false).as(LengthUnit.Meter, user, jeep);
  final you = projectOnLine(route, user);
  final bus = projectOnLine(route, jeep);
  if (you == null || bus == null) {
    // No route line: walk to the jeep itself.
    return BoardingPlan(boardAt: jeep, walkStraightM: jeepM, jeepStraightM: jeepM, onRoute: false);
  }
  final passed = bus.alongM > you.alongM;
  final stop = _stopToBoardAt(route, stops, user, you, passed ? null : bus);
  final board = stop?.position ?? you;
  final ahead = bus.alongM <= board.alongM;
  return BoardingPlan(
    boardAt: stop?.stop.location ?? you.point,
    stopName: stop?.stop.name,
    walkStraightM: stop?.walkM ?? you.offsetM,
    jeepStraightM: jeepM,
    onRoute: true,
    jeepToBoardM: ahead ? board.alongM - bus.alongM : null,
    jeepPath: ahead ? sliceLine(route, bus, board) : const [],
  );
}

/// About how many steps a walk of [metres] takes.
int stepsFor(double metres) => (metres / metresPerStep).round();

/// Minutes for the jeep to cover [metres] at [speedKmh] (slow/unknown -> 15 km/h city pace).
int jeepMinutes(double metres, double? speedKmh) {
  final kmh = (speedKmh == null || speedKmh < 5) ? 15.0 : speedKmh;
  return math.max(1, (metres / 1000 / kmh * 60).round());
}
