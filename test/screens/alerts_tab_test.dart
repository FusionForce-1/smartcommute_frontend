import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/providers/alerts_provider.dart';
import 'package:smartcommute_app/screens/commuter/alert.dart';
import 'package:smartcommute_app/services/alerts_service.dart';
import 'package:smartcommute_app/widgets/commuter/alert_card.dart';
import 'package:smartcommute_app/widgets/commuter/alert_details_sheet.dart';

import '../support/commuter_fixtures.dart';
import '../support/fake_dio.dart';

Future<AlertsProvider> pumpAlertsTab(
  WidgetTester tester,
  FakeAdapter backend, {
  bool isGuest = false,
}) async {
  tester.view.physicalSize = const Size(430, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final alerts = AlertsProvider(service: AlertsService(fakeDio(backend)), isGuest: isGuest);
  addTearDown(alerts.dispose);
  // Real async work (the fake HTTP call) must run outside the test clock.
  await tester.runAsync(alerts.load);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider.value(value: alerts, child: const AlertsTab()),
    ),
  ));
  return alerts;
}

void main() {
  testWidgets('shows the unread count and every alert', (tester) async {
    await pumpAlertsTab(tester, fakeBackend({'GET /alerts/feed': sampleFeed()}));

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('4 unread'), findsOneWidget);
    expect(find.byType(AlertCard), findsNWidgets(5));
    expect(find.text('Route Suspended'), findsOneWidget);
    expect(find.text('2 min ago'), findsOneWidget);
  });

  testWidgets('Mark all read clears the unread count', (tester) async {
    await pumpAlertsTab(
      tester,
      fakeBackend({'GET /alerts/feed': sampleFeed(), 'POST /alerts/read-all': {'updated': 4}}),
    );

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(find.text('0 unread'), findsOneWidget);
  });

  Future<void> tapFilter(WidgetTester tester, String label) async {
    final pill = find.widgetWithText(InkWell, label);
    await tester.ensureVisible(pill); // the pill row scrolls sideways on phones
    await tester.tap(pill);
    await tester.pump();
  }

  testWidgets('filters narrow the list', (tester) async {
    await pumpAlertsTab(tester, fakeBackend({'GET /alerts/feed': sampleFeed()}));

    await tapFilter(tester, 'Resolved');

    expect(find.byType(AlertCard), findsOneWidget);
    expect(find.text('Incident Cleared'), findsOneWidget);

    await tapFilter(tester, 'Critical');
    expect(find.text('Route Suspended'), findsOneWidget);
    expect(find.byType(AlertCard), findsOneWidget);
  });

  testWidgets('tapping an alert marks it read and opens its details', (tester) async {
    final backend = fakeBackend({'GET /alerts/feed': sampleFeed(), 'POST /alerts/a1/read': null});
    await pumpAlertsTab(tester, backend);

    await tester.tap(find.text('Route Suspended'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDetailsSheet), findsOneWidget);
    expect(find.textContaining('Cebu City Transport Co.'), findsOneWidget);
    expect(calls(backend), contains('POST /alerts/a1/read'));
    expect(find.text('3 unread'), findsOneWidget);
  });

  testWidgets('an empty filter says so', (tester) async {
    await pumpAlertsTab(tester, fakeBackend({'GET /alerts/feed': [alertJson('a1')]}));

    await tapFilter(tester, 'Warning');

    expect(find.text('No warning alerts right now.'), findsOneWidget);
  });

  testWidgets('a failed load offers Try again', (tester) async {
    await pumpAlertsTab(tester, fakeBackend({'GET /alerts/feed': 500}));

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('guests see alerts without unread count or Mark all read', (tester) async {
    await pumpAlertsTab(tester, fakeBackend({'GET /alerts': sampleFeed()}), isGuest: true);

    expect(find.byType(AlertCard), findsNWidgets(5));
    expect(find.textContaining('unread'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
  });
}
