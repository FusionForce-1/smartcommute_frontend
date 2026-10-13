import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/providers/trip_plan_provider.dart';
import 'package:smartcommute_app/screens/commuter/find_routes_screen.dart';
import 'package:smartcommute_app/screens/commuter/route.dart';
import 'package:smartcommute_app/screens/commuter/route_map_screen.dart';
import 'package:smartcommute_app/services/location_source.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';
import 'package:smartcommute_app/widgets/commuter/commuter_primary_button.dart';
import 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart';

import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';
import '../support/trip_plan_fixtures.dart';

const itPark = LatLng(10.33, 123.905);

bool isEnabled(WidgetTester tester, String label) =>
    tester.widget<CommuterPrimaryButton>(find.widgetWithText(CommuterPrimaryButton, label)).onPressed !=
    null;

Future<TripPlanProvider> pumpRouteTab(
  WidgetTester tester, {
  FakeLocationSource? location,
}) async {
  // Tall window so the whole Plan Your Route form is laid out.
  tester.view.physicalSize = const Size(430, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final provider = TripPlanProvider(
    service: TripPlanService(fakeDio(FakeAdapter((_) async => jsonBody(sampleResponse())))),
    locationSource: location ?? FakeLocationSource(result: const LatLng(10.31, 123.89)),
  );
  addTearDown(provider.dispose);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider<TripPlanProvider>.value(
        value: provider,
        child: const RouteTab(stops: [], routes: []),
      ),
    ),
  ));
  return provider;
}

void main() {
  testWidgets('Find Routes stays disabled until a destination is chosen', (tester) async {
    final provider = await pumpRouteTab(tester);
    expect(isEnabled(tester, 'Find Routes'), isFalse);

    provider.setDestination(itPark, 'IT Park');
    await tester.pump();

    expect(find.text('IT Park'), findsOneWidget);
    expect(isEnabled(tester, 'Find Routes'), isTrue);
  });

  testWidgets('Find Routes locates the commuter, plans and shows the options', (tester) async {
    final provider = await pumpRouteTab(tester);
    provider.setDestination(itPark, 'IT Park');
    await tester.pump();

    await tester.tap(find.text('Find Routes'));
    await tester.pumpAndSettle();

    expect(find.byType(FindRoutesScreen), findsOneWidget);
    expect(find.text('Route Options'), findsOneWidget);
    expect(find.text('Your location → IT Park'), findsOneWidget);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('01K'), findsOneWidget);
    expect(find.text('13C'), findsOneWidget);
    expect(find.text('₱28'), findsOneWidget);
    expect(find.text('~25 min'), findsOneWidget);
    expect(find.text('1 transfer'), findsOneWidget);
  });

  testWidgets('View Selected Route on Map opens the map with the fare breakdown', (tester) async {
    final provider = await pumpRouteTab(tester);
    provider.setDestination(itPark, 'IT Park');
    await tester.pump();
    await tester.tap(find.text('Find Routes'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('View Selected Route on Map'));
    await tester.pumpAndSettle();

    expect(find.byType(RouteMapScreen), findsOneWidget);
    expect(find.byType(FareBreakdownSheet), findsOneWidget);
  });

  testWidgets('a planned destination shows up in Recent Searches', (tester) async {
    final provider = await pumpRouteTab(tester);
    expect(find.text('Recent Searches'), findsNothing);

    provider.setDestination(itPark, 'IT Park');
    await tester.pump();
    await tester.tap(find.text('Find Routes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    provider.setDestination(const LatLng(10.29, 123.9), 'Colon');
    await tester.pump();
    expect(find.text('Recent Searches'), findsOneWidget);

    await tester.tap(find.text('IT Park'));
    await tester.pump();
    expect(provider.destinationLabel, 'IT Park');
  });

  testWidgets('swap is enabled once both ends are set', (tester) async {
    final provider = await pumpRouteTab(tester);
    IconButton swap() => tester.widget<IconButton>(
          find.ancestor(of: find.byIcon(Icons.swap_horiz), matching: find.byType(IconButton)),
        );
    expect(swap().onPressed, isNull);

    await provider.locateOrigin();
    provider.setDestination(itPark, 'IT Park');
    await tester.pump();
    expect(swap().onPressed, isNotNull);

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pump();
    expect(provider.originLabel, 'IT Park');
    expect(provider.destinationLabel, 'Your location');
  });

  testWidgets('a location error stays on the form and offers settings', (tester) async {
    final provider = await pumpRouteTab(
      tester,
      location: FakeLocationSource(failure: LocationFailure.denied),
    );
    provider.setDestination(itPark, 'IT Park');
    await tester.pump();

    await tester.tap(find.text('Find Routes'));
    await tester.pumpAndSettle();

    expect(find.byType(FindRoutesScreen), findsNothing);
    expect(find.text('Location permission is needed to plan a trip.'), findsOneWidget);
    expect(find.text('Open settings'), findsOneWidget);
  });

  testWidgets('hides Open settings where the platform cannot open them (web)', (tester) async {
    final provider = await pumpRouteTab(
      tester,
      location: FakeLocationSource(failure: LocationFailure.denied, canOpenSettings: false),
    );
    await provider.locateOrigin();
    await tester.pump();

    expect(find.text('Location permission is needed to plan a trip.'), findsOneWidget);
    expect(find.text('Open settings'), findsNothing);
  });

  testWidgets('empty stop list shows a helpful message in the search sheet', (tester) async {
    await pumpRouteTab(tester);

    await tester.tap(find.text('Enter destination...'));
    await tester.pumpAndSettle();

    expect(find.text('No stops available yet. Try "Pick on map".'), findsOneWidget);
  });

  testWidgets('Change departure time explains it is not available yet', (tester) async {
    await pumpRouteTab(tester);

    await tester.tap(find.text('Change'));
    await tester.pump();

    expect(find.text('Scheduling a later departure is coming soon.'), findsOneWidget);
  });
}
