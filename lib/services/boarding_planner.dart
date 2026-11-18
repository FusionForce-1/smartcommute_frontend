// Boarding planner
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/transport_model.dart' show RouteStop;

const double metresPerStep = 0.75;

const double walkMetresPerSecond = 1.3;

const double stopOnLineM = 60;

const double stopExtraWalkM = 200;

/// Format km
String formatKm(double metres) {
  final km = metres / 1000;
  return '${km.toStringAsFixed(km < 10 ? 2 : 1)} km';
}

/// Route position
class RoutePosition {
  /// Create route position
  const RoutePosition({required this.point, required this.alongM, required this.offsetM, required this.segment});

  final LatLng point;

  final double alongM;

  final double offsetM;

  final int segment;
}

/// Boarding plan
class BoardingPlan {
  /// Create boarding plan
  const BoardingPlan({
    required this.boardAt,
    required this.walkStraightM,
    required this.jeepStraightM,
    required this.onRoute,
    this.stopName,
    this.jeepToBoardM,
    this.jeepPath = const [],
  });

  final LatLng boardAt;

  final String? stopName;

  final double walkStraightM;

  final double jeepStraightM;

  final bool onRoute;

  final double? jeepToBoardM;

  final List<LatLng> jeepPath;

  bool get jeepPassed => onRoute && jeepToBoardM == null;
}

/// M per deg lat
double _mPerDegLat() => 111320.0;
/// M per deg lng
double _mPerDegLng(double lat) => 111320.0 * math.cos(lat * math.pi / 180);

/// Project on line
RoutePosition? projectOnLine(List<LatLng> line, LatLng p) {
  if (line.length < 2) return null;
  final kx = _mPerDegLng(p.latitude), ky = _mPerDegLat();
  /// Boarding planner x
  double x(LatLng q) => (q.longitude - p.longitude) * kx;
  /// Boarding planner y
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

/// Slice line
List<LatLng> sliceLine(List<LatLng> line, RoutePosition from, RoutePosition to) {
  return [from.point, for (var i = from.segment + 1; i <= to.segment; i++) line[i], to.point];
}

/// Heading against line
bool headingAgainstLine(List<LatLng> line, RoutePosition at, double heading, {double limit = 90}) {
  final along = const Distance().bearing(line[at.segment], line[at.segment + 1]);
  return ((heading - along + 540) % 360 - 180).abs() > limit;
}

/// Line as driven
List<LatLng> lineAsDriven(List<LatLng> line, {required LatLng jeep, required LatLng user, double? heading}) {
  final bus = projectOnLine(line, jeep);
  if (bus == null) return line;
  final backwards = heading != null
      ? headingAgainstLine(line, bus, heading)
      : bus.alongM > (projectOnLine(line, user)?.alongM ?? bus.alongM);
  return backwards ? line.reversed.toList() : line;
}

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

/// Plan boarding
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

/// Steps for
int stepsFor(double metres) => (metres / metresPerStep).round();

/// Jeep minutes
int jeepMinutes(double metres, double? speedKmh) {
  final kmh = (speedKmh == null || speedKmh < 5) ? 15.0 : speedKmh;
  return math.max(1, (metres / 1000 / kmh * 60).round());
}
