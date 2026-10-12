import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/providers/trip_plan_provider.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';

import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';
import '../support/trip_plan_fixtures.dart';

const start = LatLng(10.3160, 123.8900);
const destination = LatLng(10.3010, 123.8962);
// ~55 m and ~165 m south of [start]
const nearby = LatLng(10.3155, 123.8900);
const farther = LatLng(10.3145, 123.8900);

/// Serves the next queued response for each /trip-plan request.
class _Server {
  final List<Map<String, dynamic>?> queue = [];
  late final FakeAdapter adapter = FakeAdapter((options) async {
    final next = queue.isEmpty ? recommenderResponse() : queue.removeAt(0);
    return next == null ? jsonBody({'detail': 'boom'}, status: 500) : jsonBody(next);
  });
  int get calls => adapter.requests.length;
}

Future<(TripPlanProvider, FakeLocationSource, _Server)> planned() async {
  final server = _Server();
  final location = FakeLocationSource(result: start);
  final provider = TripPlanProvider(
    service: TripPlanService(fakeDio(server.adapter)),
    locationSource: location,
    refreshInterval: const Duration(hours: 1), // tests trigger refreshes themselves
  );
  await provider.locateOrigin();
  provider.setDestination(destination, 'CNU');
  await provider.plan();
  return (provider, location, server);
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('parses the recommender fields', () async {
    final (provider, _, _) = await planned();
    final leg = provider.options.single.legs.single;
    expect(leg.routeCode, '07B');
    expect(leg.walkToBoardM, 120);
    expect(leg.waitMin, 4);
    expect(leg.waitIsLive, isTrue);
    expect(leg.path, hasLength(3));
    expect(boardingSummary(leg), 'Walk 120 m to Capitol  •  Next jeep 4 min (live)');
    expect(provider.options.single.walkFromAlightM, 60);
  });

  test('traffic and arrival time are parsed and summarised', () {
    final json = recommenderResponse();
    final option = (json['options'] as List).first as Map<String, dynamic>;
    option['arrive_at'] = '2026-10-12T08:20:00.5';
    final leg = (option['legs'] as List).first as Map<String, dynamic>;
    leg.addAll({'traffic': 'heavy', 'speed_kmh': 9.0, 'speed_source': 'typical',
                'traffic_delay_min': 6, 'congestion_reported': true});

    final parsed = TripPlanResponse.fromJson(json).options.single;
    expect(parsed.arriveAt, DateTime.utc(2026, 10, 12, 8, 20, 0, 500));
    expect(parsed.legs.single.speedIsLive, isFalse);
    expect(trafficSummary(parsed), 'Heavy traffic (+6 min)  •  Congestion reported');
  });

  test('no traffic data, no traffic summary', () {
    expect(trafficSummary(TripPlanResponse.fromJson(sampleResponse()).options.first), isNull);
  });

  test('typical wait is labelled as an estimate', () {
    final leg = TripPlanResponse.fromJson(recommenderResponse(live: false, waitMin: 10))
        .options.single.legs.single;
    expect(boardingSummary(leg), 'Walk 120 m to Capitol  •  ~10 min wait');
  });

  test('older responses without the new fields still parse', () {
    final leg = TripPlanResponse.fromJson(sampleResponse()).options.first.legs.last;
    expect(leg.path, isNull);
    expect(leg.waitIsLive, isFalse);
    expect(boardingSummary(leg), isNull);
  });

  test('re-plans once the commuter has moved 100 m, not for small moves', () async {
    final (provider, location, server) = await planned();
    provider.startLiveUpdates();
    expect(provider.isFollowingLocation, isTrue);

    location.positions.add(nearby);
    await settle();
    expect(server.calls, 1, reason: '55 m is not enough to re-plan');

    location.positions.add(farther);
    await settle();
    expect(server.calls, 2);
    expect(provider.origin, farther);
    provider.dispose();
  });

  test('a closer stop after moving shows a notice and keeps the option selected', () async {
    final (provider, location, server) = await planned();
    provider.startLiveUpdates();
    server.queue.add(recommenderResponse(boardId: 'b2', boardName: 'Capitol BRT Station'));

    location.positions.add(farther);
    await settle();

    expect(provider.options.single.legs.single.boardStop.name, 'Capitol BRT Station');
    expect(provider.selectedOption, same(provider.options.single));
    expect(provider.updateNotice, 'Closer stop now: Capitol BRT Station');
    provider.dismissUpdateNotice();
    expect(provider.updateNotice, isNull);
    provider.dispose();
  });

  test('refresh updates the live wait without a loading state', () async {
    final (provider, _, server) = await planned();
    server.queue.add(recommenderResponse(waitMin: 1));
    final statuses = <TripPlanStatus>[];
    provider.addListener(() => statuses.add(provider.status));

    await provider.refresh();

    expect(statuses, isNot(contains(TripPlanStatus.loading)));
    expect(provider.options.single.legs.single.waitMin, 1);
    expect(provider.updateNotice, isNull, reason: 'same route, same stop');
  });

  test('a failed background refresh keeps the last results', () async {
    final (provider, _, server) = await planned();
    server.queue.add(null); // HTTP 500

    await provider.refresh();

    expect(provider.status, TripPlanStatus.success);
    expect(provider.options, hasLength(1));
    expect(provider.isRefreshing, isFalse);
  });

  test('a chosen stop as origin does not follow GPS', () async {
    final (provider, location, server) = await planned();
    provider.setOrigin(start, 'Cebu Provincial Capitol');
    provider.startLiveUpdates();
    expect(provider.isFollowingLocation, isFalse);

    location.positions.add(farther);
    await settle();
    expect(server.calls, 1);
  });

  test('stopLiveUpdates stops following', () async {
    final (provider, location, server) = await planned();
    provider.startLiveUpdates();
    provider.stopLiveUpdates();
    expect(provider.isFollowingLocation, isFalse);

    location.positions.add(farther);
    await settle();
    expect(server.calls, 1);
  });
}
