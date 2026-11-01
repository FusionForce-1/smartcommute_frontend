import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/driver_dashboard.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/providers/driver_provider.dart';
import 'package:smartcommute_app/providers/load_state.dart';
import 'package:smartcommute_app/services/driver_service.dart';

import '../support/commuter_fixtures.dart';
import '../support/driver_fixtures.dart';
import '../support/fake_dio.dart';

/// A backend whose answers the test can change, e.g. the operator starting the shift.
class Backend {
  Backend(this.routes);

  final Map<String, Object?> routes;
  late final FakeAdapter adapter = FakeAdapter((options) => fakeBackend(routes).handler(options));
}

DriverProvider buildProvider(Backend backend, {FakeGpsSession? gps, DateTime Function()? clock}) =>
    DriverProvider(DriverService(fakeDio(backend.adapter)), gps: gps ?? FakeGpsSession(), clock: clock);

Backend backendWith({Map<String, dynamic>? shift, List<Map<String, dynamic>>? vehicles, Map<String, Object?> extra = const {}}) =>
    Backend({
      'GET /drivers/me': dashboardJson(shift: shift, vehicles: vehicles),
      'GET /notifications': <Map<String, dynamic>>[],
      ...extra,
    });

VehicleLiveUpdate frame({String source = 'tracker', String status = 'en_route', bool shiftEnded = false}) =>
    VehicleLiveUpdate(
      vehicleId: 'v1',
      status: status,
      location: shiftEnded || status == 'signal_lost' ? null : const LatLng(10.3, 123.9),
      source: source,
      shiftEnded: shiftEnded,
    );

void main() {
  test('load shows the driver, their vehicle and route', () async {
    final driver = buildProvider(backendWith(vehicles: [vehicleJson(), vehicleJson(id: 'v2', plate: 'DEF 456')]));

    await driver.load();

    expect(driver.loadState, LoadState.ready);
    expect(driver.name, 'Juan Dela Cruz');
    expect(driver.vehicles.length, 2);
    expect(driver.vehicle!.plateNumber, 'ABC 123');
    expect(driver.vehicle!.routeLine, 'Talamban → Pier 1 Terminal');
    expect(driver.onShift, isFalse);
  });

  test('a shift the operator started is shown, on its own vehicle', () async {
    final driver = buildProvider(backendWith(
      vehicles: [vehicleJson(), vehicleJson(id: 'v2', plate: 'DEF 456')],
      shift: shiftJson(vehicleId: 'v2', crowd: 60, passengers: 4),
    ));

    await driver.load();

    expect(driver.vehicle!.plateNumber, 'DEF 456');
    expect(driver.crowdPercent, 60);
    expect(driver.shift!.passengers, 4);
  });

  test("the phone backs up the tracker while a shift is open, and stops after", () async {
    final gps = FakeGpsSession();
    final backend = backendWith();
    final driver = buildProvider(backend, gps: gps);
    await driver.load();
    expect(gps.started, isEmpty, reason: 'no shift, no GPS');

    backend.routes['GET /drivers/me'] = dashboardJson(shift: shiftJson());   // operator starts the shift
    await driver.refresh();
    expect(driver.onShift, isTrue);
    expect(gps.started, ['v1']);

    await driver.refresh();
    expect(gps.started, ['v1'], reason: 'started once');

    backend.routes['GET /drivers/me'] = dashboardJson();                     // operator ends it
    await driver.refresh();
    expect(driver.onShift, isFalse);
    expect(gps.stops, 1);
  });

  test("a jeep without a tracker gets no phone backup (the backend would refuse it)", () async {
    final gps = FakeGpsSession();
    final driver = buildProvider(backendWith(shift: shiftJson(), vehicles: [vehicleJson(hasTracker: false)]), gps: gps);

    await driver.load();

    expect(driver.onShift, isTrue);
    expect(gps.started, isEmpty);
    expect(driver.gpsError, DriverProvider.noTrackerMessage);
  });

  test('the distance driven comes from the server, refreshed with the dashboard', () async {
    final backend = backendWith(shift: shiftJson(distanceKm: 4.2));
    final driver = buildProvider(backend);
    await driver.load();
    expect(driver.shift!.distanceKm, 4.2);

    backend.routes['GET /drivers/me'] = dashboardJson(shift: shiftJson(distanceKm: 5.7));
    await driver.refresh();
    expect(driver.shift!.distanceKm, 5.7);
  });

  test('a refused location permission is shown and only retried on request', () async {
    final gps = FakeGpsSession(startError: Exception('Location permission denied.'));
    final driver = buildProvider(backendWith(shift: shiftJson()), gps: gps);

    await driver.load();
    expect(driver.onShift, isTrue);
    expect(driver.gpsError, 'Location permission denied.');

    gps.startError = null;
    await driver.refresh();
    expect(gps.started, isEmpty, reason: "a refresh doesn't ask again");

    await driver.retryPhoneGps();
    expect(gps.started, ['v1']);
    expect(driver.gpsError, isNull);
  });

  test('where the GPS comes from follows the live feed', () async {
    var now = DateTime(2026, 10, 27, 8);
    final driver = buildProvider(backendWith(shift: shiftJson()), clock: () => now);
    await driver.load();
    expect(driver.jeepGps, JeepGps.none);

    driver.onLiveFrame(frame());
    expect(driver.jeepGps, JeepGps.tracker);

    driver.onLiveFrame(frame(source: 'phone'));
    expect(driver.jeepGps, JeepGps.phone);

    now = now.add(const Duration(minutes: 1));     // nothing since
    expect(driver.jeepGps, JeepGps.none);

    driver.onLiveFrame(frame());
    driver.onLiveFrame(frame(status: 'signal_lost'));
    expect(driver.jeepGps, JeepGps.none);
  });

  test('frames of other jeeps are ignored', () async {
    final driver = buildProvider(backendWith(shift: shiftJson()));
    await driver.load();

    driver.onLiveFrame(const VehicleLiveUpdate(vehicleId: 'other', status: 'en_route', location: LatLng(10.3, 123.9)));

    expect(driver.live, isNull);
  });

  test('a shift ended on the live feed is picked up right away', () async {
    final gps = FakeGpsSession();
    final backend = backendWith(shift: shiftJson());
    final driver = buildProvider(backend, gps: gps);
    await driver.load();

    backend.routes['GET /drivers/me'] = dashboardJson();
    driver.onLiveFrame(frame(shiftEnded: true));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(driver.onShift, isFalse);
    expect(gps.stops, 1);
  });

  test('a failed first load is an error', () async {
    final driver = buildProvider(Backend({'GET /drivers/me': 500}));

    await driver.load();

    expect(driver.loadState, LoadState.error);
    expect(driver.loadError, 'Request failed');
  });

  test('updates are loaded, and can be marked read', () async {
    final backend = backendWith(extra: {
      'GET /notifications': [updateJson(), updateJson(id: 'n2', read: true)],
      'POST /notifications/read-all': {'updated': 1},
    });
    final driver = buildProvider(backend);
    await driver.load();

    expect(driver.updates.map((u) => u.title), ['Your shift started', 'Your shift started']);
    expect(driver.unreadUpdates, 1);

    await driver.markUpdatesRead();
    expect(driver.unreadUpdates, 0);
    expect(calls(backend.adapter), contains('POST /notifications/read-all'));
  });

  test('crowd and passengers need a shift', () async {
    final backend = backendWith();
    final driver = buildProvider(backend);
    await driver.load();

    expect(await driver.commitCrowd(40), DriverProvider.noShiftMessage);
    expect(await driver.changePassengers(1), DriverProvider.noShiftMessage);
    expect(calls(backend.adapter).where((c) => c.contains('/shift/')), isEmpty);
  });

  test('crowd is saved where the slider is let go, and rolled back on failure', () async {
    final ok = buildProvider(backendWith(shift: shiftJson(), extra: {'PUT /drivers/me/shift/crowd': {'percent': 60}}));
    await ok.load();
    ok.previewCrowd(55);
    expect(ok.crowdPercent, 55);
    expect(await ok.commitCrowd(60), isNull);
    expect(ok.crowdPercent, 60);

    final failing = buildProvider(backendWith(shift: shiftJson(), extra: {'PUT /drivers/me/shift/crowd': 500}));
    await failing.load();
    await failing.commitCrowd(80);
    expect(failing.crowdPercent, 0);
  });

  test('passenger count follows the server, and a refused tap is undone', () async {
    final ok = buildProvider(backendWith(shift: shiftJson(), extra: {'POST /drivers/me/shift/passengers': {'passengers': 7}}));
    await ok.load();
    await ok.changePassengers(1);
    expect(ok.shift!.passengers, 7);

    final failing = buildProvider(backendWith(shift: shiftJson(), extra: {'POST /drivers/me/shift/passengers': 500}));
    await failing.load();
    expect(await failing.changePassengers(1), 'Request failed');
    expect(failing.shift!.passengers, 0);
  });

  test('profile details: email, operator and most recent route', () async {
    final driver = buildProvider(Backend({
      'GET /drivers/me': dashboardJson(recentRoute: vehicleJson(id: 'v9', plate: 'KEN-124')),
      'GET /notifications': <Map<String, dynamic>>[],
    }));
    await driver.load();

    expect(driver.email, 'juan.delacruz@smartcommute.ph');
    expect(driver.operator!.companyName, 'Cebu Transit Co');
    expect(driver.operator!.ownerName, 'John');
    expect(driver.recentRoute!.plateNumber, 'KEN-124');
  });

  group('route status', () {
    test('is Unavailable off shift and can only change during one', () async {
      final backend = backendWith();
      final driver = buildProvider(backend);
      await driver.load();

      expect(driver.routeStatus, RouteStatus.unavailable);
      expect(await driver.setRouteStatus(RouteStatus.delayed), DriverProvider.noShiftMessage);
      expect(calls(backend.adapter), isNot(contains('PUT /drivers/me/shift/status')));
    });

    test('is saved, and rolled back if the server refuses it', () async {
      final ok = buildProvider(backendWith(shift: shiftJson(), extra: {'PUT /drivers/me/shift/status': {'status': 'delayed'}}));
      await ok.load();
      expect(ok.routeStatus, RouteStatus.onRoute);
      expect(await ok.setRouteStatus(RouteStatus.delayed), isNull);
      expect(ok.routeStatus, RouteStatus.delayed);

      final failing = buildProvider(backendWith(shift: shiftJson(), extra: {'PUT /drivers/me/shift/status': 500}));
      await failing.load();
      expect(await failing.setRouteStatus(RouteStatus.delayed), 'Request failed');
      expect(failing.routeStatus, RouteStatus.onRoute);
    });
  });

  group('updates by period', () {
    final now = DateTime(2026, 10, 29, 15, 30);
    final today = DateTime(2026, 10, 29);

    test('each period covers the right days', () {
      expect(updatesRange(UpdatesPeriod.recent, now), (since: null, until: null));
      expect(updatesRange(UpdatesPeriod.today, now), (since: today, until: null));
      expect(updatesRange(UpdatesPeriod.yesterday, now), (since: DateTime(2026, 10, 28), until: today));
      expect(updatesRange(UpdatesPeriod.lastMonth, now).since, DateTime(2026, 9, 29));
      expect(updatesRange(UpdatesPeriod.lastYear, now).since, DateTime(2025, 10, 29));
      expect(
        updatesRange(UpdatesPeriod.day, now, day: DateTime(2026, 10, 3)),
        (since: DateTime(2026, 10, 3), until: DateTime(2026, 10, 4)),
      );
    });

    test('picking one asks the server for that period', () async {
      final backend = backendWith();
      final driver = buildProvider(backend, clock: () => now);
      await driver.load();

      await driver.showUpdates(UpdatesPeriod.day, day: DateTime(2026, 10, 3));

      final query = backend.adapter.requests.lastWhere((r) => r.path == '/notifications').queryParameters;
      expect(DateTime.parse(query['since'] as String), DateTime(2026, 10, 3).toUtc());
      expect(DateTime.parse(query['until'] as String), DateTime(2026, 10, 4).toUtc());
      expect(driver.updatesPeriod, UpdatesPeriod.day);
      expect(driver.updatesDay, DateTime(2026, 10, 3));
    });
  });

  test('distance to the next stop comes from the live feed and the route stops', () async {
    final driver = buildProvider(backendWith(shift: shiftJson(), extra: {
      'GET /routes/r1': {
        'id': 'r1',
        'name': 'Talamban – Pier 1',
        'code': 'J02',
        'is_active': true,
        'geometry': {'type': 'LineString', 'coordinates': [[123.9, 10.3], [123.9, 10.31]]},
        'stops': [
          {'id': 's1', 'name': 'Pier 1', 'sequence': 1, 'location': {'type': 'Point', 'coordinates': [123.9, 10.301]}},
        ],
      },
    }));
    await driver.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));   // the route line
    expect(driver.distanceToNextStopM, isNull);

    driver.onLiveFrame(const VehicleLiveUpdate(
        vehicleId: 'v1', status: 'en_route', location: LatLng(10.3, 123.9), nextStop: 'Pier 1'));

    expect(driver.distanceToNextStopM, closeTo(111, 2));   // 0.001° of latitude
  });
}
