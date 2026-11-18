// Trip ETA
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/models.dart' show StopModel;
import '../models/transport_model.dart';
import '../models/trip_plan.dart';
import 'boarding_planner.dart';
import 'trip_progress.dart';

typedef LiveJeep = ({String id, String routeId, LatLng at, double? heading});

/// Trip ETA
class TripEta {
  /// Create trip ETA
  const TripEta({
    required this.minutes,
    required this.arriveAt,
    this.walkMin,
    this.waitMin,
    this.jeepId,
    this.jeepInMin,
    this.rideLeftMin,
  });

  final int minutes;
  final DateTime arriveAt;

  final int? walkMin;
  final int? waitMin;

  final String? jeepId;
  final int? jeepInMin;

  final int? rideLeftMin;

  bool get waitIsLive => jeepId != null;
  bool get atStop => walkMin == 0;
}

const double walkMPerMin = 75;
const double walkDetour = 1.25;

const int usualWaitMin = 10;

const double atStopM = 30;

const double jeepOffRouteM = 150;

/// Trip ETA
TripEta? tripEta({
  required RouteOption option,
  required TripProgressState progress,
  required LatLng here,
  required DateTime now,
  required Map<String, TransportRoute> routesById,
  Iterable<LiveJeep> jeeps = const [],
}) {
  if (progress.phase == TripPhase.arrived || option.legs.isEmpty) return null;
  final index = progress.legIndex.clamp(0, option.legs.length - 1);
  final leg = option.legs[index];
  final speed = _mPerMin(leg);

  var after = option.walkFromAlightMin ?? 0;
  for (final next in option.legs.skip(index + 1)) {
    after += (next.walkToBoardMin ?? 0) + (next.waitMin ?? usualWaitMin) + _rideMin(next);
  }

  /// Trip ETA done
  TripEta done(int minutes, {int? walk, int? wait, String? jeep, int? jeepIn, int? rideLeft}) => TripEta(
        minutes: minutes,
        arriveAt: now.add(Duration(minutes: minutes)),
        walkMin: walk,
        waitMin: wait,
        jeepId: jeep,
        jeepInMin: jeepIn,
        rideLeftMin: rideLeft,
      );

  if (progress.isRiding) {
    final rideLeft = (progress.remainingM / speed).ceil();
    return done(rideLeft + after, rideLeft: rideLeft);
  }

  final board = _at(leg.boardStop);
  final toStopM = board == null ? 0.0 : const Distance(roundResult: false).as(LengthUnit.Meter, here, board);
  final walk = toStopM <= atStopM ? 0 : (toStopM * walkDetour / walkMPerMin).ceil();
  final next = board == null ? null : _nextJeep(leg, board, walk, speed, routesById[leg.routeId], jeeps);
  final wait = next == null
      ? (leg.waitIsLive ? usualWaitMin : leg.waitMin ?? usualWaitMin)
      : math.max(0, (next.minutes - walk).ceil());
  return done(walk + wait + _rideMin(leg) + after,
      walk: walk, wait: wait, jeep: next?.id, jeepIn: next?.minutes.ceil());
}

({String id, double minutes})? _nextJeep(
  RouteLeg leg,
  LatLng board,
  int walkMin,
  double speed,
  TransportRoute? route,
  Iterable<LiveJeep> jeeps,
) {
  if (route == null || route.geometry.length < 2) return null;
  final line = leg.isReturn ? route.geometry.reversed.toList() : route.geometry;
  final stop = projectOnLine(line, board);
  if (stop == null) return null;
  ({String id, double minutes})? best;
  for (final jeep in jeeps) {
    if (jeep.routeId != leg.routeId) continue;
    final at = projectOnLine(line, jeep.at);
    if (at == null || at.offsetM > jeepOffRouteM) continue;
    if (jeep.heading case final heading? when headingAgainstLine(line, at, heading)) continue;
    final toStop = stop.alongM - at.alongM;
    if (toStop < -atStopM / 2) continue;
    final minutes = toStop <= atStopM ? 0.0 : toStop / speed;
    if (minutes + 0.5 < walkMin) continue;
    if (best == null || minutes < best.minutes) best = (id: jeep.id, minutes: minutes);
  }
  return best;
}

/// M per min
double _mPerMin(RouteLeg leg) {
  final kmh = leg.speedKmh;
  if (kmh != null && kmh >= 5) return kmh * 1000 / 60;
  final km = leg.rideKm, min = leg.rideMin;
  if (km != null && min != null && min > 0) return km * 1000 / min;
  return 15 * 1000 / 60;
}

/// Ride min
int _rideMin(RouteLeg leg) {
  final km = leg.rideKm;
  if (km != null) return math.max(1, (km * 1000 / _mPerMin(leg)).ceil());
  return leg.rideMin ?? 0;
}

/// Trip ETA at
LatLng? _at(StopModel stop) => stop.isPlaceholder ? null : LatLng(stop.location.lat, stop.location.lng);
