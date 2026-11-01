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
import 'package:smartcommute_app/screens/driver/driver_map_tab.dart';
import 'package:smartcommute_app/services/location_source.dart';
import 'package:smartcommute_app/models/driver_dashboard.dart';
import 'package:smartcommute_app/services/driver_service.dart';
import 'package:smartcommute_app/services/profile_service.dart';
import 'package:smartcommute_app/widgets/commuter/commuter_nav_bar.dart';

import '../support/commuter_fixtures.dart';
import '../support/driver_fixtures.dart';
import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';

/// The dashboard against a fake backend; [backend] records every request.
Future<({DriverProvider driver, FakeAdapter backend})> pumpDashboard(
  WidgetTester tester,
  Map<String, Object?> routes, {
  VoidCallback? onSignOut,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);

  final backend = fakeBackend({'GET /notifications': <Map<String, dynamic>>[], ...routes});
  final dio = fakeDio(backend);
  final driver = DriverProvider(DriverService(dio), gps: FakeGpsSession());
  await tester.runAsync(driver.load);
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider.value(
      value: driver,
      child: DriverDashboardView(onSignOut: onSignOut ?? () {}, profileService: ProfileService(dio)),
    ),
  ));
  await settle(tester);   // the route line request
  return (driver: driver, backend: backend);
}

/// Opens a bottom-navigation tab.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(CommuterNavBar), matching: find.text(label)));
  await settle(tester);
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

  // ── Map tab ────────────────────────────────────────────────

  testWidgets('off shift: the map, Not on shift, and locked Route Status and crowd', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': dashboardJson()});

    expect(find.text('Driver Dashboard'), findsOneWidget);
    expect(find.byKey(const Key('mapExpandToggle')), findsOneWidget);
    await reveal(tester, find.byKey(const Key('offShift')));
    expect(find.text('Not on shift'), findsOneWidget);

    await reveal(tester, find.byKey(const Key('routeStatusCard')));
    expect(find.text('You can change this once your shift starts.'), findsOneWidget);
    await reveal(tester, find.text('Crowd Activity Estimate'));
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);
  });

  testWidgets('on shift: passengers and crowd are live', (tester) async {
    await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson()),
      'POST /drivers/me/shift/passengers': {'passengers': 1},
    });

    await reveal(tester, find.byKey(const Key('onShift')));
    expect(find.text('On Shift'), findsOneWidget);

    await tapAndWait(tester, find.text('1 Passenger'));
    expect(find.text('Passengers: 1'), findsOneWidget);
    await reveal(tester, find.text('Crowd Activity Estimate'));
    expect(find.text('0% Full'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);
  });

  testWidgets('Route Status: picking Delayed saves it', (tester) async {
    final (:driver, :backend) = await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson()),
      'PUT /drivers/me/shift/status': {'status': 'delayed'},
    });
    expect(driver.routeStatus, RouteStatus.onRoute);

    await tapAndWait(tester, find.byKey(const Key('routeStatus_delayed')));

    expect(driver.routeStatus, RouteStatus.delayed);
    final put = backend.requests.lastWhere((r) => r.method == 'PUT');
    expect(put.data, {'status': 'delayed'});
  });

  testWidgets('the shift card shows the distance, and explains a jeep without a tracker', (tester) async {
    await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson(distanceKm: 4.2), vehicles: [vehicleJson(hasTracker: false)]),
    });

    await reveal(tester, find.text('Distance: 4.2 km'));
    expect(find.text('Distance: 4.2 km'), findsOneWidget);
    await reveal(tester, find.text(DriverProvider.noTrackerMessage));
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('the shift card says where the GPS is coming from', (tester) async {
    final (:driver, backend: _) = await pumpDashboard(tester, {'GET /drivers/me': dashboardJson(shift: shiftJson())});
    await reveal(tester, find.byKey(const Key('jeepGps')));
    expect(find.text('No GPS from the jeep right now'), findsOneWidget);

    driver.onLiveFrame(const VehicleLiveUpdate(
        vehicleId: 'v1', status: 'en_route', location: LatLng(10.3, 123.9), source: 'phone'));
    await tester.pump();

    expect(find.text("Tracker offline — sharing your phone's location"), findsOneWidget);
  });

  testWidgets('full screen: My Route sheet, minimized to its handle, and back', (tester) async {
    final (:driver, backend: _) = await pumpDashboard(tester, {'GET /drivers/me': dashboardJson(shift: shiftJson())});
    driver.onLiveFrame(const VehicleLiveUpdate(
        vehicleId: 'v1', status: 'en_route', location: LatLng(10.3, 123.9), nextStop: 'Pier 1', etaNextStop: 4));

    await tester.tap(find.byKey(const Key('mapExpandToggle')));
    await settle(tester);

    final sheet = find.byKey(const Key('myRouteSheet'));
    expect(sheet, findsOneWidget);
    expect(find.text('Driver Dashboard'), findsNothing);
    expect(find.text('My Route'), findsOneWidget);
    expect(find.text('J02 · Talamban → Pier 1 Terminal'), findsOneWidget);
    expect(find.text('Pier 1'), findsOneWidget);
    expect(find.text('4 min'), findsOneWidget);

    final opened = tester.getTopLeft(sheet).dy;
    await tester.tap(find.byKey(const Key('myRouteSheetHandle')));
    await settle(tester);
    expect(tester.getTopLeft(sheet).dy, greaterThan(opened));

    await tester.tap(find.byKey(const Key('mapExpandToggle')));
    await settle(tester);
    expect(sheet, findsNothing);
    expect(find.text('Driver Dashboard'), findsOneWidget);
  });

  group('Centre on my location', () {
    /// Just the Map tab, with a fake phone location.
    Future<void> pumpMapTab(WidgetTester tester, FakeLocationSource location) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      final driver = DriverProvider(
        DriverService(fakeDio(fakeBackend({
          'GET /drivers/me': dashboardJson(),
          'GET /notifications': <Map<String, dynamic>>[],
        }))),
        gps: FakeGpsSession(),
      );
      await tester.runAsync(driver.load);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: DriverMapTab(driver: driver, locationSource: location)),
      ));
      await settle(tester);
    }

    testWidgets('is there off shift, on the card and full screen', (tester) async {
      await pumpDashboard(tester, {'GET /drivers/me': dashboardJson()});
      expect(find.byTooltip('Center on my location'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mapExpandToggle')));
      await settle(tester);
      expect(find.byTooltip('Center on my location'), findsOneWidget);
    });

    testWidgets('with no jeep position it shows where the phone is', (tester) async {
      await pumpMapTab(tester, FakeLocationSource(result: const LatLng(10.3, 123.9)));
      expect(find.byKey(const Key('driverMyLocation')), findsNothing);

      await tester.tap(find.byTooltip('Center on my location'));
      await settle(tester);

      expect(find.byKey(const Key('driverMyLocation')), findsOneWidget);
    });

    testWidgets('says why when location is not allowed', (tester) async {
      await pumpMapTab(tester, FakeLocationSource(failure: LocationFailure.denied));

      await tester.tap(find.byTooltip('Center on my location'));
      await settle(tester);

      expect(find.text('Allow location for SmartCommute to see where you are on the map.'), findsOneWidget);
    });
  });

  // ── Updates tab ────────────────────────────────────────────

  testWidgets('Updates: listed with their date, filtered by period, read when leaving', (tester) async {
    final (driver: _, :backend) = await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson()),
      'GET /notifications': [updateJson()],
      'POST /notifications/read-all': {'updated': 1},
    });

    await openTab(tester, 'Updates');
    expect(find.text('Your shift started'), findsOneWidget);
    expect(find.textContaining('min ago ('), findsOneWidget);
    for (final chip in ['Recent', 'Today', 'Yesterday', 'Last Month', 'Last Year']) {
      expect(find.text(chip), findsOneWidget);
    }
    expect(find.text('Select Date'), findsOneWidget);

    await tester.tap(find.text('Today'));
    await settle(tester);
    final query = backend.requests.lastWhere((r) => r.path == '/notifications').queryParameters;
    expect(query['since'], isNotNull);
    expect(query.containsKey('until'), isFalse);

    expect(backend.requests.any((r) => r.path == '/notifications/read-all'), isFalse);
    await openTab(tester, 'Map');
    expect(backend.requests.any((r) => r.path == '/notifications/read-all'), isTrue);
  });

  // ── Profile tab ────────────────────────────────────────────

  testWidgets('Profile: who the driver is, their route, operator and account links', (tester) async {
    var signedOut = 0;
    await pumpDashboard(
      tester,
      {
        'GET /drivers/me': dashboardJson(
          recentRoute: vehicleJson(id: 'v9', plate: 'KEN-124')..['route_code'] = 'KEN',
        ),
      },
      onSignOut: () => signedOut++,
    );

    await openTab(tester, 'Profile');
    expect(find.text('JC'), findsOneWidget);   // first + last name
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('juan.delacruz@smartcommute.ph'), findsOneWidget);
    expect(find.text('Route: J02'), findsOneWidget);
    expect(find.text('Vehicle: ABC 123'), findsOneWidget);
    expect(find.text('Driver'), findsOneWidget);
    expect(find.text('J02 · ABC 123'), findsOneWidget);
    expect(find.text('Cebu Transit Co'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
    expect(find.text('KEN · KEN-124'), findsOneWidget);

    await reveal(tester, find.text('Sign out'));
    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(find.text('Help & Support'), findsOneWidget);
    expect(find.text('Terms & Privacy Policy'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    expect(signedOut, 1);
  });

  testWidgets('Help & Support has driver questions', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': dashboardJson()});
    await openTab(tester, 'Profile');
    await reveal(tester, find.text('Help & Support'));
    await tester.tap(find.text('Help & Support'));
    await settle(tester);
    expect(find.text('What does Route Status do?'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': 500});

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
