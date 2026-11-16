// The selected trip's live ETA (lib/services/trip_eta.dart): walking to /
// waiting at the stop, then riding.

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/models.dart' show GeoJSONPoint, StopModel;
import 'package:smartcommute_app/models/transport_model.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/services/trip_eta.dart';
import 'package:smartcommute_app/services/trip_progress.dart';

// Route r runs east along lat 10.300 from 123.870 to 123.910 at 15 km/h
// (250 m/min). The trip boards at 123.880 and gets off at 123.910 (~3.3 km,
// 14 min), then walks 2 min.
const lat = 10.300;
const mPerDegLng = 111320 * 0.98389; // cos(10.3°)
final now = DateTime.utc(2026, 11, 16, 8);

StopModel stop(String name, double lng) =>
    StopModel(id: name, name: name, sequence: 1, location: GeoJSONPoint(lat: lat, lng: lng));

final route = TransportRoute(
  id: 'r', name: 'Route r', code: '07B', isActive: true, stops: const [],
  geometry: [for (var i = 0; i <= 40; i++) LatLng(lat, 123.870 + i * 0.001)],
);

RouteLeg leg({double board = 123.880, double alight = 123.910, String direction = 'outbound', String routeId = 'r'}) =>
    RouteLeg(
      routeId: routeId, routeName: 'Route r', routeCode: '07B', direction: direction,
      boardStop: stop('Board', board), alightStop: stop('Alight', alight),
      etaMin: 24, fare: 17, waitMin: 10, rideKm: ((alight - board).abs() * mPerDegLng / 1000), rideMin: 14,
      speedKmh: 15,
    );

RouteOption option(List<RouteLeg> legs) =>
    RouteOption(rank: 1, legs: legs, totalEtaMin: 26, totalFare: 17, transfers: legs.length - 1, walkFromAlightMin: 2);

TripProgressState phase(TripPhase p, {int legIndex = 0, double remaining = 0}) =>
    TripProgressState(phase: p, legIndex: legIndex, alongM: 0, remainingM: remaining, speedKmh: null);

LiveJeep jeep(String id, double lng, {double? heading = 90, String routeId = 'r'}) =>
    (id: id, routeId: routeId, at: LatLng(lat, lng), heading: heading);

/// 150 m north of the boarding stop: a 3 min walk (with the street detour).
final nearStop = LatLng(lat + 150 / 111320, 123.880);

TripEta? eta(RouteOption o, TripProgressState p, LatLng here, [List<LiveJeep> jeeps = const []]) =>
    tripEta(option: o, progress: p, here: here, now: now, routesById: {'r': route}, jeeps: jeeps);

void main() {
  test('walking to the stop: walk, wait for the next live jeep, ride, walk', () {
    // ~1.1 km before the stop: there in ~4.4 min, after the 3 min walk.
    final e = eta(option([leg()]), phase(TripPhase.toBoard), nearStop, [jeep('j1', 123.870)])!;
    expect(e.walkMin, 3);
    expect(e.jeepId, 'j1');
    expect(e.jeepInMin, 5);
    expect(e.waitMin, 2);
    expect(e.minutes, 3 + 2 + 14 + 2);
    expect(e.arriveAt, now.add(const Duration(minutes: 21)));
  });

  test('without a live jeep coming it uses the usual wait', () {
    final passed = jeep('passed', 123.885);                  // already past the stop
    final otherWay = jeep('west', 123.875, heading: 270);    // driving the other way
    final otherRoute = jeep('x', 123.875, routeId: 'q');
    final e = eta(option([leg()]), phase(TripPhase.toBoard), nearStop, [passed, otherWay, otherRoute])!;
    expect(e.jeepId, isNull);
    expect(e.waitMin, 10);
    expect(e.minutes, 3 + 10 + 14 + 2);
  });

  test("skips a jeep that reaches the stop before the commuter can", () {
    final e = eta(option([leg()]), phase(TripPhase.toBoard), nearStop,
        [jeep('missed', 123.8795), jeep('next', 123.870)])!;
    expect(e.jeepId, 'next');
  });

  test('waiting at the stop: just the wait, the ride and the walk', () {
    final e = eta(option([leg()]), phase(TripPhase.toBoard), const LatLng(lat, 123.880), [jeep('j1', 123.870)])!;
    expect(e.walkMin, 0);
    expect(e.waitMin, 5);
    expect(e.minutes, 0 + 5 + 14 + 2);
  });

  test('a jeep at the stop now means no wait', () {
    final e = eta(option([leg()]), phase(TripPhase.toBoard), const LatLng(lat, 123.880), [jeep('j1', 123.8799)])!;
    expect(e.jeepInMin, 0);
    expect(e.waitMin, 0);
  });

  test('on the jeep: the ride left at the route speed, then the walk', () {
    final e = eta(option([leg()]), phase(TripPhase.riding, remaining: 1000), const LatLng(lat, 123.900))!;
    expect(e.rideLeftMin, 4);
    expect(e.minutes, 4 + 2);
    expect(e.walkMin, isNull);
  });

  test('riding the first of two legs adds the transfer, the wait and the second ride', () {
    final second = RouteLeg(
      routeId: 'q', routeName: 'Route q', boardStop: stop('T', 123.910), alightStop: stop('End', 123.950),
      etaMin: 18, fare: 17, walkToBoardMin: 3, waitMin: 10, rideMin: 8, speedKmh: 15,
    );
    final e = eta(option([leg(), second]), phase(TripPhase.alightSoon, remaining: 500), const LatLng(lat, 123.905))!;
    expect(e.minutes, 2 + (3 + 10 + 8) + 2);
  });

  test('the way back is the line driven the other way', () {
    // Return trip: boards at 123.900 going west; a westbound jeep at 123.905 is coming.
    final back = leg(board: 123.900, alight: 123.875, direction: 'return');
    final e = eta(option([back]), phase(TripPhase.toBoard), const LatLng(lat, 123.900),
        [jeep('east', 123.895), jeep('coming', 123.905, heading: 270)])!;
    expect(e.jeepId, 'coming');
    expect(e.waitMin, 3);   // ~550 m at 250 m/min
  });

  test('no ETA once arrived', () {
    expect(eta(option([leg()]), phase(TripPhase.arrived), const LatLng(lat, 123.910)), isNull);
  });
}
