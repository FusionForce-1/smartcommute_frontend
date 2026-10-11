import 'package:flutter_test/flutter_test.dart';
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
  });
}
