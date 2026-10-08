import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/providers/trip_plan_provider.dart';
import 'package:smartcommute_app/services/location_source.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';

import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';
import '../support/trip_plan_fixtures.dart';

const origin = LatLng(10.31, 123.89);
const destination = LatLng(10.33, 123.905);

TripPlanProvider buildProvider(FakeAdapter adapter, {FakeLocationSource? location}) {
  return TripPlanProvider(
    service: TripPlanService(fakeDio(adapter)),
    locationSource: location ?? FakeLocationSource(result: origin),
  );
}

class _HangingLocationSource implements LocationSource {
  @override
  Future<LatLng> currentLocation() => Completer<LatLng>().future;

  @override
  Future<void> openSettings() async {}

  @override
  bool get canOpenSettings => true;
}

FakeAdapter okAdapter() => FakeAdapter((_) async => jsonBody(sampleResponse()));

Future<TripPlanProvider> readyProvider(FakeAdapter adapter) async {
  final provider = buildProvider(adapter);
  await provider.locateOrigin();
  provider.setDestination(destination, 'IT Park');
  return provider;
}

void main() {
  group('locateOrigin', () {
    test('sets origin on success', () async {
      final provider = buildProvider(okAdapter());

      await provider.locateOrigin();

      expect(provider.origin, origin);
      expect(provider.locationError, isNull);
      expect(provider.isLocating, isFalse);
    });

    test('permission denied sets message and keeps planning disabled', () async {
      final provider = buildProvider(
        okAdapter(),
        location: FakeLocationSource(failure: LocationFailure.denied),
      );

      await provider.locateOrigin();
      provider.setDestination(destination, 'IT Park');

      expect(provider.origin, isNull);
      expect(provider.locationError, 'Location permission is needed to plan a trip.');
      expect(provider.canPlan, isFalse);
    });

    test('location services off sets message', () async {
      final provider = buildProvider(
        okAdapter(),
        location: FakeLocationSource(failure: LocationFailure.servicesOff),
      );

      await provider.locateOrigin();

      expect(provider.locationError, 'Turn on location services to plan a trip.');
    });

    test('a GPS lookup that never answers times out with a message', () async {
      final provider = TripPlanProvider(
        service: TripPlanService(fakeDio(okAdapter())),
        locationSource: _HangingLocationSource(),
        locateTimeout: const Duration(milliseconds: 10),
      );

      await provider.locateOrigin();

      expect(provider.isLocating, isFalse);
      expect(provider.origin, isNull);
      expect(provider.locationError, 'Unable to get your current location.');
    });

    test('openLocationSettings delegates to the location source', () async {
      final location = FakeLocationSource(result: origin);
      final provider = buildProvider(okAdapter(), location: location);

      await provider.openLocationSettings();

      expect(location.settingsOpened, 1);
    });
  });

  group('plan', () {
    test('does nothing without a destination', () async {
      final adapter = okAdapter();
      final provider = buildProvider(adapter);
      await provider.locateOrigin();

      await provider.plan();

      expect(adapter.requests, isEmpty);
      expect(provider.status, TripPlanStatus.idle);
    });

    test('success stores options and allows selecting one', () async {
      final provider = await readyProvider(okAdapter());

      await provider.plan();

      expect(provider.status, TripPlanStatus.success);
      expect(provider.options, hasLength(1));
      expect(provider.selectedOption, isNull);

      provider.selectOption(provider.options.single);
      expect(provider.selectedOption, same(provider.options.single));
    });

    test('sends the chosen preference', () async {
      final adapter = okAdapter();
      final provider = await readyProvider(adapter);

      provider.setPreference(TripPreference.fare);
      await provider.plan();

      final body = adapter.requests.single.data as Map<String, dynamic>;
      expect((body['preferences'] as Map)['minimize'], 'fare');
    });

    test('empty options sets empty status', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody(emptyResponse())),
      );

      await provider.plan();

      expect(provider.status, TripPlanStatus.empty);
      expect(provider.options, isEmpty);
    });

    test('401 maps to the sign-in message', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody({'detail': 'no'}, status: 401)),
      );

      await provider.plan();

      expect(provider.status, TripPlanStatus.error);
      expect(provider.errorMessage, 'Sign in as a commuter to plan trips.');
    });

    test('403 maps to the sign-in message', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody({'detail': 'no'}, status: 403)),
      );

      await provider.plan();

      expect(provider.errorMessage, 'Sign in as a commuter to plan trips.');
    });

    test('connection error maps to the offline message', () async {
      final provider = await readyProvider(
        FakeAdapter((options) async => throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            )),
      );

      await provider.plan();

      expect(provider.errorMessage, "Can't reach the server. Check your connection.");
    });

    test('500 maps to the generic message', () async {
      final provider = await readyProvider(
        FakeAdapter((_) async => jsonBody({'detail': 'boom'}, status: 500)),
      );

      await provider.plan();

      expect(provider.errorMessage, 'Something went wrong. Please try again.');
    });

    test('destination within 20 m is blocked without a request', () async {
      final adapter = okAdapter();
      final provider = buildProvider(adapter);
      await provider.locateOrigin();
      provider.setDestination(const LatLng(10.31004, 123.89), 'Right here');

      await provider.plan();

      expect(adapter.requests, isEmpty);
      expect(provider.status, TripPlanStatus.error);
      expect(provider.errorMessage, "You're already there.");
    });

    test('double tap sends only one request', () async {
      final gate = Completer<ResponseBody>();
      final adapter = FakeAdapter((_) => gate.future);
      final provider = await readyProvider(adapter);

      final first = provider.plan();
      final second = provider.plan();
      expect(provider.canPlan, isFalse);
      gate.complete(jsonBody(sampleResponse()));
      await Future.wait([first, second]);

      expect(adapter.requests, hasLength(1));
      expect(provider.status, TripPlanStatus.success);
    });

    test('changing destination mid-request ignores the stale response', () async {
      final gate = Completer<ResponseBody>();
      final provider = await readyProvider(FakeAdapter((_) => gate.future));

      final pending = provider.plan();
      provider.setDestination(const LatLng(10.29, 123.9), 'Colon');
      gate.complete(jsonBody(sampleResponse()));
      await pending;

      expect(provider.status, TripPlanStatus.idle);
      expect(provider.options, isEmpty);
      expect(provider.destinationLabel, 'Colon');
    });

    test('changing preference mid-request ignores the stale response', () async {
      final gate = Completer<ResponseBody>();
      final provider = await readyProvider(FakeAdapter((_) => gate.future));

      final pending = provider.plan();
      provider.setPreference(TripPreference.transfers);
      gate.complete(jsonBody(sampleResponse()));
      await pending;

      expect(provider.status, TripPlanStatus.idle);
      expect(provider.options, isEmpty);
    });

    test('new destination clears previous results and selection', () async {
      final provider = await readyProvider(okAdapter());
      await provider.plan();
      provider.selectOption(provider.options.single);

      provider.setDestination(const LatLng(10.29, 123.9), 'Colon');

      expect(provider.options, isEmpty);
      expect(provider.selectedOption, isNull);
      expect(provider.status, TripPlanStatus.idle);
    });

    test('disposing mid-request does not throw', () async {
      final gate = Completer<ResponseBody>();
      final provider = await readyProvider(FakeAdapter((_) => gate.future));

      final pending = provider.plan();
      provider.dispose();
      gate.complete(jsonBody(sampleResponse()));

      await expectLater(pending, completes);
    });
  });
}
