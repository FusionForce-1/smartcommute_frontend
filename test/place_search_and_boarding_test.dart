import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/transport_model.dart' show RouteStop;
import 'package:smartcommute_app/services/boarding_planner.dart';
import 'package:smartcommute_app/services/place_search.dart';

void main() {
  group('landmark search (From / To)', () {
    // The real bundled list, so these check the data as well as the matching.
    final index = PlaceIndex.fromLandmarkJson(
      jsonDecode(File('assets/data/cebu_landmarks.json').readAsStringSync()) as Map<String, dynamic>,
    );
    const cebu = LatLng(10.3157, 123.8854);

    List<String> top(String q, [int n = 3]) =>
        index.search(q, near: cebu, limit: n).map((m) => m.place.name).toList();

    test('finds well-known Cebu landmarks, not just saved stops', () {
      expect(top('sm city cebu', 1).single, 'SM City Cebu');
      expect(top('ayala', 5), contains('Ayala Center Cebu'));
      expect(top('south bus', 1).single, 'Cebu South Bus Terminal');
      expect(top('basilica', 1).single, startsWith('Basilica Minore del Santo Niño'));
    });

    test('matches word starts and ignores accents and case', () {
      expect(top('sm ceb', 1).single, 'SM City Cebu');
      expect(index.search('santo nino', near: cebu).every((m) => foldPlaceText(m.place.name).contains('santo nino')), isTrue);
      expect(foldPlaceText('Santo Niño!'), 'santo nino');
    });

    test('nearest first, one hit per name, nothing for nonsense', () {
      final hits = index.search('fuente', near: cebu, limit: 8);
      final names = hits.map((m) => foldPlaceText(m.place.name)).toList();
      expect(names.toSet().length, names.length);
      expect(index.search('xyzzy qqq', near: cebu), isEmpty);
      expect(index.search('a', near: cebu), isEmpty, reason: 'needs 2+ letters');
    });

    test('nearest named place for a boarding spot', () {
      final carbon = index.search('carbon market unit 3', near: cebu, limit: 1).single.place;
      final hit = index.nearest(carbon.location, maxMetres: 20);
      expect(hit, isNotNull);
      expect(index.nearest(const LatLng(10.0, 123.0)), isNull, reason: 'out at sea: nothing within 150 m');
    });
  });

  group('boarding plan (Nearby Vehicles)', () {
    // A straight east-west route, ~2.2 km long, along latitude 10.30.
    final route = [for (var i = 0; i <= 20; i++) LatLng(10.30, 123.88 + i * 0.001)];
    const user = LatLng(10.3027, 123.890);   // ~300 m north of the route, at its middle

    test('boards at the closest point on the route, not at the jeep', () {
      const jeep = LatLng(10.30, 123.882);    // west end, heading east
      final plan = planBoarding(route: route, user: user, jeep: jeep);
      expect(plan.onRoute, isTrue);
      expect(plan.boardAt.latitude, closeTo(10.30, 1e-6));
      expect(plan.boardAt.longitude, closeTo(123.890, 1e-6));
      expect(plan.walkStraightM, closeTo(300, 5));
      expect(plan.jeepToBoardM, closeTo(876, 10));     // 0.008° of longitude at 10.3°N
      expect(plan.jeepPath.first, jeep);
      expect(plan.jeepPath.last.longitude, closeTo(123.890, 1e-6));
    });

    test('a jeep already past the boarding spot is reported as passed', () {
      final plan = planBoarding(route: route, user: user, jeep: const LatLng(10.30, 123.895));
      expect(plan.jeepPassed, isTrue);
      expect(plan.jeepPath, isEmpty);
    });

    test('no route line: walk to the jeep itself', () {
      const jeep = LatLng(10.30, 123.882);
      final plan = planBoarding(route: const [], user: user, jeep: jeep);
      expect(plan.onRoute, isFalse);
      expect(plan.boardAt, jeep);
    });

    test('knows how far the jeep is from the commuter', () {
      const jeep = LatLng(10.30, 123.882);
      final plan = planBoarding(route: route, user: user, jeep: jeep);
      expect(plan.jeepStraightM, closeTo(925, 10));   // 876 m along the street, 300 m across
    });

    RouteStop stop(String name, double lng, {double lat = 10.30}) =>
        RouteStop(id: name, name: name, sequence: 1, location: LatLng(lat, lng));

    test('boards at the nearest stop when it is barely further', () {
      const jeep = LatLng(10.30, 123.882);
      final plan = planBoarding(route: route, user: user, jeep: jeep, stops: [stop('Near', 123.891), stop('Far', 123.899)]);
      expect(plan.stopName, 'Near');
      expect(plan.boardAt.longitude, closeTo(123.891, 1e-6));
      expect(plan.walkStraightM, closeTo(316, 10));
      expect(plan.jeepToBoardM, closeTo(986, 10));
      expect(plan.jeepPath.last.longitude, closeTo(123.891, 1e-6));
    });

    test('a stop much further than the route is not worth the walk', () {
      final plan = planBoarding(
        route: route, user: user, jeep: const LatLng(10.30, 123.882), stops: [stop('Far', 123.899)],
      );
      expect(plan.stopName, isNull);
      expect(plan.boardAt.longitude, closeTo(123.890, 1e-6));
    });

    test('skips stops the jeep has passed, and stops off the route', () {
      const jeep = LatLng(10.30, 123.8895);
      final plan = planBoarding(route: route, user: user, jeep: jeep, stops: [
        stop('Behind the jeep', 123.889),
        stop('Off the route', 123.890, lat: 10.3015),
        stop('Ahead', 123.8915),
      ]);
      expect(plan.stopName, 'Ahead');
    });

    test('a jeep that has passed still leaves a stop to wait at for the next one', () {
      final plan = planBoarding(route: route, user: user, jeep: const LatLng(10.30, 123.895), stops: [stop('Near', 123.891)]);
      expect(plan.jeepPassed, isTrue);
      expect(plan.stopName, 'Near');
    });

    test('a jeep driving back along the route is coming, not gone', () {
      const jeep = LatLng(10.30, 123.895);   // east of the commuter, heading west
      final line = lineAsDriven(route, jeep: jeep, user: user, heading: 270);
      expect(line.first, route.last);
      final plan = planBoarding(route: line, user: user, jeep: jeep);
      expect(plan.jeepPassed, isFalse);
      expect(plan.jeepToBoardM, closeTo(547, 10));
    });

    test('a jeep driving away along the route has passed', () {
      const jeep = LatLng(10.30, 123.895);   // east of the commuter, heading east
      final line = lineAsDriven(route, jeep: jeep, user: user, heading: 90);
      expect(line.first, route.first);
      expect(planBoarding(route: line, user: user, jeep: jeep).jeepPassed, isTrue);
    });

    test('a jeep that has not moved yet is taken to be coming', () {
      const jeep = LatLng(10.30, 123.895);
      final line = lineAsDriven(route, jeep: jeep, user: user);
      expect(planBoarding(route: line, user: user, jeep: jeep).jeepPassed, isFalse);
    });

    test('distances read in km', () {
      expect(formatKm(350), '0.35 km');
      expect(formatKm(1250), '1.25 km');
      expect(formatKm(12400), '12.4 km');
    });

    test('steps and jeep minutes', () {
      expect(stepsFor(300), 400);                 // 0.75 m per step
      expect(jeepMinutes(1000, 30), 2);
      expect(jeepMinutes(1000, 0), 4, reason: 'stopped/unknown speed -> 15 km/h city pace');
      expect(jeepMinutes(10, 30), 1, reason: 'never shows 0 min');
    });
  });
}
