// The Driver Dashboard against a fake backend. The shift card animates
// forever (live dot), so these pump fixed durations instead of pumpAndSettle.

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/providers/driver_provider.dart';
import 'package:smartcommute_app/screens/driver/driver_dashboard_view.dart';
import 'package:smartcommute_app/services/driver_service.dart';

import '../support/commuter_fixtures.dart';
import '../support/driver_fixtures.dart';
import '../support/fake_dio.dart';

Future<DriverProvider> pumpDashboard(WidgetTester tester, Map<String, Object?> routes) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final driver = DriverProvider(
    DriverService(fakeDio(fakeBackend({'GET /notifications': <Map<String, dynamic>>[], ...routes}))),
    gps: FakeGpsSession(),
  );
  await tester.runAsync(driver.load);
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider.value(
      value: driver,
      child: DriverDashboardView(onSignOut: () {}),
    ),
  ));
  await settle(tester);   // the map's route request
  return driver;
}

/// Lets the fake backend (real time) answer and the frames after it run.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Scrolls the screen's list until [finder] is built and on screen. Scrolls
/// the list itself: a drag could land on the map and pan it instead.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  final position = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
  while (finder.evaluate().isEmpty && position.pixels < position.maxScrollExtent) {
    position.jumpTo(math.min(position.pixels + 200, position.maxScrollExtent));
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// Taps [finder], then lets the fake backend answer.
Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
  await reveal(tester, finder);
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  setUp(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=http://test');
    // The map's tile cache asks path_provider for a folder; tests have no plugins.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.path,
    );
  });

  testWidgets('off shift: the map, the driver, their route, and no shift controls', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': dashboardJson()});

    expect(find.text('Driver Dashboard'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.byTooltip('Full screen'), findsOneWidget);
    await reveal(tester, find.byKey(const Key('offShift')));
    expect(find.text('Not on shift'), findsOneWidget);
    expect(find.text('START SHIFT'), findsNothing);
    expect(find.text('Crowd Activity Estimate'), findsNothing);
    await reveal(tester, find.text('My Route'));
    expect(find.text('J02 · ABC 123'), findsOneWidget);
  });

  testWidgets('on shift: no END SHIFT, but crowd and passengers', (tester) async {
    await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson()),
      'POST /drivers/me/shift/passengers': {'passengers': 1},
    });

    await reveal(tester, find.byKey(const Key('onShift')));
    expect(find.text('On Shift'), findsOneWidget);
    expect(find.text('END SHIFT'), findsNothing);

    await tapAndWait(tester, find.text('1 Passenger'));
    expect(find.text('Passengers: 1'), findsOneWidget);
    await reveal(tester, find.text('Crowd Activity Estimate'));
    expect(find.text('0% Full'), findsOneWidget);
  });

  testWidgets('the shift card says where the GPS is coming from', (tester) async {
    final driver = await pumpDashboard(tester, {'GET /drivers/me': dashboardJson(shift: shiftJson())});
    await reveal(tester, find.byKey(const Key('jeepGps')));
    expect(find.text('No GPS from the jeep right now'), findsOneWidget);

    driver.onLiveFrame(const VehicleLiveUpdate(
        vehicleId: 'v1', status: 'en_route', location: LatLng(10.3, 123.9), source: 'phone'));
    await tester.pump();

    expect(find.text("Tracker offline — sharing your phone's location"), findsOneWidget);
  });

  testWidgets('updates from the operator are listed', (tester) async {
    await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson()),
      'GET /notifications': [updateJson()],
    });

    await reveal(tester, find.text('Updates'));
    expect(find.text('Your shift started'), findsOneWidget);
    expect(find.text('Mark all read'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': 500});

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
