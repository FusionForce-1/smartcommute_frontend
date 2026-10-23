// The Driver Dashboard against a fake backend. The Shift Active card
// animates forever (live dot), so these pump fixed durations instead of
// pumpAndSettle.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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

  final driver = DriverProvider(DriverService(fakeDio(fakeBackend(routes))), gps: FakeGpsSession());
  await tester.runAsync(driver.load);
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider.value(
      value: driver,
      child: DriverDashboardView(onSignOut: () {}),
    ),
  ));
  return driver;
}

/// Scrolls the screen's list until [finder] is built and fully on screen.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pump();
}

/// Taps [finder], then lets chained work finish: the fake backend answers
/// on real time, and animations / navigation need frames in between.
Future<void> tapAndWait(WidgetTester tester, Finder finder, {bool scroll = true}) async {
  if (scroll) await reveal(tester, finder);
  await tester.tap(finder);
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('shows the driver, their vehicle and START SHIFT', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': dashboardJson()});

    expect(find.text('Driver Dashboard'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('Route: J02'), findsOneWidget);
    expect(find.text('Vehicle: ABC 123'), findsOneWidget);
    expect(find.text('Share your location with commuters'), findsOneWidget);
    expect(find.text('0% Full'), findsOneWidget);
    await reveal(tester, find.text('View My Route on Map'));
    expect(find.text('START SHIFT'), findsOneWidget);
  });

  testWidgets('reporting a status before the shift asks to start it', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': dashboardJson()});

    await tapAndWait(tester, find.text('Delayed'));

    expect(find.text('Start your shift first.'), findsOneWidget);
  });

  testWidgets('a full shift: start, count a passenger, end, see the summary', (tester) async {
    await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(),
      'POST /drivers/me/shift': shiftJson(),
      'POST /drivers/me/shift/passengers': {'passengers': 1},
      'POST /drivers/me/shift/end': summaryJson(),
    });

    await tapAndWait(tester, find.text('START SHIFT'));
    await reveal(tester, find.text('END SHIFT'));
    expect(find.text('Shift Active'), findsOneWidget);

    await tapAndWait(tester, find.text('1 Passenger'));
    expect(find.text('Passengers: 1'), findsOneWidget);

    await tapAndWait(tester, find.text('END SHIFT'));
    expect(find.text('End Shift?'), findsOneWidget);
    await tapAndWait(tester, find.widgetWithText(FilledButton, 'End Shift'), scroll: false);

    expect(find.text('Shift Complete'), findsOneWidget);
    expect(find.text('01:20:04'), findsOneWidget);
    expect(find.text('1.1km'), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
    expect(find.text('Route J02 Summary'), findsOneWidget);
    expect(find.text('Talamban → Pier 1 Terminal'), findsOneWidget);
    expect(find.text('60% avg occupancy'), findsOneWidget);
    expect(find.text('Active throughout shift'), findsOneWidget);

    await tapAndWait(tester, find.text('Start New Shift'), scroll: false);
    await reveal(tester, find.text('START SHIFT'));
    expect(find.text('START SHIFT'), findsOneWidget);
  });

  testWidgets('a shift in progress shows the distance driven so far', (tester) async {
    await pumpDashboard(tester, {
      'GET /drivers/me': dashboardJson(shift: shiftJson(distanceKm: 4.2), dutyStatus: 'on_route'),
    });

    await reveal(tester, find.text('Distance: 4.2 km'));

    expect(find.text('Distance: 4.2 km'), findsOneWidget);
  });

  testWidgets('a failed first load offers a retry', (tester) async {
    await pumpDashboard(tester, {'GET /drivers/me': 500});

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });
}
