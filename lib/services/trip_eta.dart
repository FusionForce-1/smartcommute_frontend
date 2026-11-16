// lib/services/trip_eta.dart
//
// The selected trip's time to the destination, kept current on the Home card
// as the commuter goes (the planner's figure is from when they picked it):
//
//   walking to / waiting at the boarding stop: the walk there, the wait for
//     the next live jeep on the route they can still catch, the ride, then
//     the rest of the trip;
//   on the jeep: the ride left at the route's traffic speed, then the rest.
//
// Same rules as the backend recommender (app/services/route_recommender.py):
// walking 75 m/min with a 1.25 street detour, the planner's usual wait when
// no live jeep is coming, and a jeep only counts if the commuter can get to
// the stop by the time it does (half a minute of slack).

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/models.dart' show StopModel;
import '../models/transport_model.dart';
import '../models/trip_plan.dart';
import 'boarding_planner.dart';
import 'trip_progress.dart';

/// A live jeep: where it is now and which way it's driving (null: unknown).
typedef LiveJeep = ({String id, String routeId, LatLng at, double? heading});

class TripEta {
  const TripEta({
    required this.minutes,
    required this.arriveAt,
    this.walkMin,
    this.waitMin,
    this.jeepId,
    this.jeepInMin,
    this.rideLeftMin,
  });

  /// To the destination.
  final int minutes;
  final DateTime arriveAt;

  /// Not on the jeep yet: the walk to the boarding stop (0 = at it) and the
  /// wait there after getting there.
  final int? walkMin;
  final int? waitMin;

  /// The next live jeep the commuter can catch, and when it reaches the stop
  /// (0 = it's there). Null: none is sending GPS, so [waitMin] is the usual wait.
  final String? jeepId;
  final int? jeepInMin;

  /// On the jeep: minutes of riding left on this leg.
  final int? rideLeftMin;

  bool get waitIsLive => jeepId != null;
  bool get atStop => walkMin == 0;
}

const double walkMPerMin = 75;
const double walkDetour = 1.25;

/// The planner's wait when no live jeep is coming (backend DEFAULT_WAIT_MIN).
const int usualWaitMin = 10;

/// This close to the boarding stop = at it (the commuter, or the jeep).
const double atStopM = 30;

/// A jeep further than this from the route line isn't driving it.
const double jeepOffRouteM = 150;

/// [option]'s time to the destination from where the commuter is ([here],
/// [progress]); null once they've arrived. [jeeps] are every live jeep;
/// only those on the current leg's route, before its boarding stop and
/// driving towards it, count.
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

  // Everything after this leg, as planned.
  var after = option.walkFromAlightMin ?? 0;
  for (final next in option.legs.skip(index + 1)) {
    after += (next.walkToBoardMin ?? 0) + (next.waitMin ?? usualWaitMin) + _rideMin(next);
  }

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

/// The soonest live jeep on [leg]'s route that reaches its boarding stop no
/// earlier than the commuter can walk there; minutes until it does.
({String id, double minutes})? _nextJeep(
  RouteLeg leg,
  LatLng board,
  int walkMin,
  double speed,
  TransportRoute? route,
  Iterable<LiveJeep> jeeps,
) {
  if (route == null || route.geometry.length < 2) return null;
  // The return trip drives the line the other way.
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
    if (toStop < -atStopM / 2) continue;                  // already past the stop
    final minutes = toStop <= atStopM ? 0.0 : toStop / speed;
    if (minutes + 0.5 < walkMin) continue;               // gone before the commuter gets there
    if (best == null || minutes < best.minutes) best = (id: jeep.id, minutes: minutes);
  }
  return best;
}

/// Metres per minute on [leg]: the route's traffic speed from the planner.
double _mPerMin(RouteLeg leg) {
  final kmh = leg.speedKmh;
  if (kmh != null && kmh >= 5) return kmh * 1000 / 60;
  final km = leg.rideKm, min = leg.rideMin;
  if (km != null && min != null && min > 0) return km * 1000 / min;
  return 15 * 1000 / 60;   // city pace
}

int _rideMin(RouteLeg leg) {
  final km = leg.rideKm;
  if (km != null) return math.max(1, (km * 1000 / _mPerMin(leg)).ceil());
  return leg.rideMin ?? 0;
}

LatLng? _at(StopModel stop) => stop.isPlaceholder ? null : LatLng(stop.location.lat, stop.location.lng);
