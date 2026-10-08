import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';

import '../support/fake_dio.dart';
import '../support/trip_plan_fixtures.dart';

void main() {
  const origin = LatLng(10.31, 123.89);
  const destination = LatLng(10.33, 123.905);

  test('POSTs /trip-plan with GeoJSON [lng, lat] and minimize', () async {
    final adapter = FakeAdapter((_) async => jsonBody(sampleResponse()));
    final service = TripPlanService(fakeDio(adapter));

    final result = await service.planTrip(
      origin: origin,
      destination: destination,
      preference: TripPreference.fare,
    );

    final request = adapter.requests.single;
    expect(request.method, 'POST');
    expect(request.path, '/trip-plan');
    final body = request.data as Map<String, dynamic>;
    expect(body['origin'], {
      'type': 'Point',
      'coordinates': [123.89, 10.31],
    });
    expect((body['destination'] as Map)['coordinates'], [123.905, 10.33]);
    expect(body['preferences'], {'minimize': 'fare', 'max_transfers': 2});
    expect(result.options.single.totalFare, 28.0);
  });

  test('defaults to minimize time', () async {
    final adapter = FakeAdapter((_) async => jsonBody(emptyResponse()));
    final service = TripPlanService(fakeDio(adapter));

    await service.planTrip(origin: origin, destination: destination);

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect((body['preferences'] as Map)['minimize'], 'time');
  });

  test('waits long enough for a cold backend to build its road graph', () async {
    final adapter = FakeAdapter((_) async => jsonBody(emptyResponse()));
    final service = TripPlanService(fakeDio(adapter));

    await service.planTrip(origin: origin, destination: destination);

    expect(
      adapter.requests.single.receiveTimeout,
      greaterThanOrEqualTo(const Duration(seconds: 60)),
    );
  });

  test('lets a 401 bubble up as DioException', () async {
    final adapter = FakeAdapter(
      (_) async => jsonBody({'detail': 'Not authenticated'}, status: 401),
    );
    final service = TripPlanService(fakeDio(adapter));

    await expectLater(
      service.planTrip(origin: origin, destination: destination),
      throwsA(isA<DioException>()),
    );
  });
}
