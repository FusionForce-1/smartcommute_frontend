import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/driver_dashboard.dart';
import 'package:smartcommute_app/providers/driver_provider.dart';
import 'package:smartcommute_app/providers/load_state.dart';
import 'package:smartcommute_app/services/driver_service.dart';

import '../support/commuter_fixtures.dart';
import '../support/driver_fixtures.dart';
import '../support/fake_dio.dart';

DriverProvider buildProvider(FakeAdapter backend, {FakeGpsSession? gps}) =>
    DriverProvider(DriverService(fakeDio(backend)), gps: gps ?? FakeGpsSession());

Future<DriverProvider> onShift(Map<String, Object?> extra, {FakeGpsSession? gps}) async {
  final driver = buildProvider(
    fakeBackend({'GET /drivers/me': dashboardJson(shift: shiftJson(), dutyStatus: 'on_route'), ...extra}),
    gps: gps,
  );
  await driver.load();
  return driver;
}

Object? lastBody(FakeAdapter backend) {
  final data = backend.requests.last.data;
  return data is String ? jsonDecode(data) : data;
}

void main() {
  test('load shows the driver and picks their first vehicle', () async {
    final driver = buildProvider(fakeBackend({
      'GET /drivers/me': dashboardJson(vehicles: [vehicleJson(), vehicleJson(id: 'v2', plate: 'DEF 456')]),
    }));

    await driver.load();

    expect(driver.loadState, LoadState.ready);
    expect(driver.name, 'Juan Dela Cruz');
    expect(driver.vehicle!.plateNumber, 'ABC 123');
    expect(driver.vehicle!.routeLine, 'Talamban → Pier 1 Terminal');
    expect(driver.onShift, isFalse);
    expect(driver.dutyStatus, DutyStatus.unavailable);
  });

  test('a shift in progress is restored, on its own vehicle', () async {
    final driver = buildProvider(fakeBackend({
      'GET /drivers/me': dashboardJson(
        vehicles: [vehicleJson(), vehicleJson(id: 'v2', plate: 'DEF 456')],
        shift: shiftJson(vehicleId: 'v2', crowd: 60, passengers: 4),
        dutyStatus: 'delayed',
      ),
    }));

    await driver.load();

    expect(driver.vehicle!.plateNumber, 'DEF 456');
    expect(driver.dutyStatus, DutyStatus.delayed);
    expect(driver.crowdPercent, 60);
    expect(driver.shift!.passengers, 4);
  });

  test('a failed first load is an error', () async {
    final driver = buildProvider(fakeBackend({'GET /drivers/me': 500}));

    await driver.load();

    expect(driver.loadState, LoadState.error);
    expect(driver.loadError, 'Request failed');
  });

  test('starting a shift puts the driver on route and turns on GPS', () async {
    final gps = FakeGpsSession();
    final backend = fakeBackend({'GET /drivers/me': dashboardJson(), 'POST /drivers/me/shift': shiftJson()});
    final driver = buildProvider(backend, gps: gps);
    await driver.load();

    final error = await driver.startShift();

    expect(error, isNull);
    expect(lastBody(backend), {'vehicle_id': 'v1'});
    expect(driver.onShift, isTrue);
    expect(driver.dutyStatus, DutyStatus.onRoute);
    expect(gps.started, ['v1']);
  });

  test('the shift still starts when GPS cannot', () async {
    final gps = FakeGpsSession(startError: Exception('Location permission denied.'));
    final driver = buildProvider(
      fakeBackend({'GET /drivers/me': dashboardJson(), 'POST /drivers/me/shift': shiftJson()}),
      gps: gps,
    );
    await driver.load();

    final error = await driver.startShift();

    expect(driver.onShift, isTrue);
    expect(error, 'Shift started, but GPS is off: Location permission denied.');
  });

  test('without a GPS tracker the shift starts but GPS stays off', () async {
    final gps = FakeGpsSession();
    final driver = buildProvider(
      fakeBackend({
        'GET /drivers/me': dashboardJson(vehicles: [vehicleJson(hasTracker: false)]),
        'POST /drivers/me/shift': shiftJson(),
      }),
      gps: gps,
    );
    await driver.load();

    final error = await driver.startShift();

    expect(driver.onShift, isTrue);
    expect(driver.canBroadcast, isFalse);
    expect(error, 'Shift started, but GPS is off: ${DriverProvider.noTrackerMessage}');
    expect(await driver.setBroadcasting(true), DriverProvider.noTrackerMessage);
    expect(gps.started, isEmpty);
  });

  test('without a vehicle there is nothing to start', () async {
    final backend = fakeBackend({'GET /drivers/me': dashboardJson(vehicles: [])});
    final driver = buildProvider(backend);
    await driver.load();

    expect(await driver.startShift(), contains('No vehicle is assigned'));
    expect(calls(backend), ['GET /drivers/me']);
  });

  test('the vehicle is locked during a shift', () async {
    final driver = buildProvider(fakeBackend({
      'GET /drivers/me': dashboardJson(
        vehicles: [vehicleJson(), vehicleJson(id: 'v2', plate: 'DEF 456')],
        shift: shiftJson(),
      ),
    }));
    await driver.load();

    driver.selectVehicle('v2');

    expect(driver.vehicle!.id, 'v1');
  });

  test('duty status, crowd and passengers need a shift', () async {
    final backend = fakeBackend({'GET /drivers/me': dashboardJson()});
    final driver = buildProvider(backend);
    await driver.load();

    expect(await driver.setDutyStatus(DutyStatus.delayed), DriverProvider.noShiftMessage);
    expect(await driver.commitCrowd(40), DriverProvider.noShiftMessage);
    expect(await driver.changePassengers(1), DriverProvider.noShiftMessage);
    expect(await driver.setBroadcasting(true), DriverProvider.noShiftMessage);
    expect(calls(backend), ['GET /drivers/me']);
  });

  test('duty status is rolled back if the server refuses it', () async {
    final driver = await onShift({'PUT /drivers/me/status': 500});

    final error = await driver.setDutyStatus(DutyStatus.delayed);

    expect(error, 'Request failed');
    expect(driver.dutyStatus, DutyStatus.onRoute);
  });

  test('crowd is saved where the slider is let go, and rolled back on failure', () async {
    final ok = await onShift({'PUT /drivers/me/shift/crowd': {'percent': 60}});
    ok.previewCrowd(55);
    expect(ok.crowdPercent, 55);
    expect(await ok.commitCrowd(60), isNull);
    expect(ok.crowdPercent, 60);

    final failing = await onShift({'PUT /drivers/me/shift/crowd': 500});
    await failing.commitCrowd(80);
    expect(failing.crowdPercent, 0);
  });

  test('passenger count follows the server', () async {
    final driver = await onShift({'POST /drivers/me/shift/passengers': {'passengers': 7}});

    await driver.changePassengers(1);

    expect(driver.shift!.passengers, 7);
  });

  test('a refused passenger tap is undone', () async {
    final driver = await onShift({'POST /drivers/me/shift/passengers': 500});

    final error = await driver.changePassengers(1);

    expect(error, 'Request failed');
    expect(driver.shift!.passengers, 0);
  });

  test('ending the shift stops GPS and returns its summary', () async {
    final gps = FakeGpsSession();
    final driver = await onShift({'POST /drivers/me/shift/end': summaryJson()}, gps: gps);

    final result = await driver.endShift();

    expect(result.error, isNull);
    expect(result.summary!.passengers, 15);
    expect(result.summary!.gpsCoverage, GpsCoverage.full);
    expect(gps.stops, 1);
    expect(driver.onShift, isFalse);
    expect(driver.dutyStatus, DutyStatus.unavailable);
  });

  test('a failed end keeps the shift open', () async {
    final driver = await onShift({'POST /drivers/me/shift/end': 500});

    final result = await driver.endShift();

    expect(result.summary, isNull);
    expect(result.error, 'Request failed');
    expect(driver.onShift, isTrue);
  });
}
