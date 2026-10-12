import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/transport_model.dart';
import 'package:smartcommute_app/models/trip_plan.dart';

import '../support/trip_plan_fixtures.dart';

void main() {
  group('TripPlanResponse.fromJson', () {
    test('parses options, legs and totals', () {
      final response = TripPlanResponse.fromJson(sampleResponse());

      final option = response.options.single;
      expect(option.rank, 1);
      expect(option.totalEtaMin, 25);
      expect(option.totalFare, 28.0);
      expect(option.transfers, 1);
      expect(option.legs, hasLength(2));
      expect(option.legs.first.routeName, '01K');
      expect(option.legs.first.alightStop.name, 'Colon');
      expect(option.routeSummary, '01K → 13C');
      expect(response.generatedAt.year, 2026);
    });

    test('accepts integer fares from the backend', () {
      final leg = TripPlanResponse.fromJson(sampleResponse()).options.single.legs[1];

      expect(leg.fare, isA<double>());
      expect(leg.fare, 15.0);
    });

    test('parses an empty options list', () {
      final response = TripPlanResponse.fromJson(emptyResponse());

      expect(response.options, isEmpty);
    });
  });

  group('StopDisplay', () {
    test('backend stub placeholder stop shows as "Your location"', () {
      final legs = TripPlanResponse.fromJson(sampleResponse()).options.single.legs;

      expect(legs.first.boardStop.isPlaceholder, isTrue);
      expect(legs.first.boardStop.displayName, 'Your location');
      expect(legs.first.alightStop.isPlaceholder, isFalse);
      expect(legs.first.alightStop.displayName, 'Colon');
    });
  });

  group('formatting', () {
    test('formatFare uses peso sign and two decimals', () {
      expect(formatFare(13), '₱13.00');
      expect(formatFare(27.5), '₱27.50');
    });

    test('formatTransfers pluralizes', () {
      expect(formatTransfers(0), 'No transfers');
      expect(formatTransfers(1), '1 transfer');
      expect(formatTransfers(2), '2 transfers');
    });

    test('TripPreference maps to backend minimize values', () {
      expect(TripPreference.time.apiValue, 'time');
      expect(TripPreference.fare.apiValue, 'fare');
      expect(TripPreference.transfers.apiValue, 'transfers');
      expect(TripPreference.time.label, 'Fastest');
    });

    test('formatFareCompact drops ".00" only for whole pesos', () {
      expect(formatFareCompact(13), '₱13');
      expect(formatFareCompact(13.5), '₱13.50');
    });
  });

  group('stopCount', () {
    RouteStop stop(String id, int sequence) =>
        RouteStop(id: id, name: id, sequence: sequence, location: const LatLng(10.3, 123.9));

    // r1: a → b → c → d ; r2: d → e → f (stops listed out of order on purpose)
    final routesById = {
      'r1': TransportRoute(
        id: 'r1', name: 'R1', code: '01K', geometry: const [], isActive: true,
        stops: [stop('c', 3), stop('a', 1), stop('d', 4), stop('b', 2)],
      ),
      'r2': TransportRoute(
        id: 'r2', name: 'R2', code: '13C', geometry: const [], isActive: true,
        stops: [stop('d', 1), stop('e', 2), stop('f', 3)],
      ),
    };

    Map<String, dynamic> leg(String routeId, String board, String alight) => {
          'route_id': routeId,
          'route_name': routeId,
          'board_stop': stopJson(board, board, 123.9, 10.3),
          'alight_stop': stopJson(alight, alight, 123.9, 10.3),
          'eta_min': 5,
          'fare': 13,
        };

    RouteOption option(List<Map<String, dynamic>> legs) => RouteOption.fromJson({
          'rank': 1,
          'legs': legs,
          'total_eta_min': 10,
          'total_fare': 26,
          'transfers': legs.length - 1,
        });

    test('adds up stops ridden on every leg, following route order', () {
      expect(option([leg('r1', 'a', 'd'), leg('r2', 'd', 'f')]).stopCount(routesById), 5);
    });

    test('is null when a stop or route is unknown', () {
      expect(option([leg('r1', '0', 'd')]).stopCount(routesById), isNull);
      expect(option([leg('r9', 'a', 'd')]).stopCount(routesById), isNull);
    });
  });
}
