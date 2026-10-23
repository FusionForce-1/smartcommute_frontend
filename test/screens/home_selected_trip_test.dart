// Home tab: a route picked with "Select this route" shows as a card and on
// the map until it's cancelled; tapping the card opens its details.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/selected_trip.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/screens/commuter/home.dart';
import 'package:smartcommute_app/screens/commuter/route_map_screen.dart';
import 'package:smartcommute_app/widgets/commuter/live_map.dart';

import '../support/trip_plan_fixtures.dart';

SelectedTrip sampleTrip() => SelectedTrip(
      option: TripPlanResponse.fromJson(sampleResponse()).options.first,
      from: 'Your location',
      to: 'IT Park',
      routesById: const {},
    );

Future<void> pumpHome(WidgetTester tester, {SelectedTrip? trip, VoidCallback? onCancel}) {
  tester.view.physicalSize = const Size(414, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: HomeTab(
        stops: const [],
        routes: const [],
        vehicles: const [],
        selectedTrip: trip,
        onCancelTrip: onCancel,
      ),
    ),
  ));
}

Finder get card => find.byKey(const Key('selectedTripCard'));

void main() {
  setUp(() => dotenv.loadFromString(
        envString: 'API_BASE_URL=http://127.0.0.1:9\nWS_BASE_URL=ws://127.0.0.1:9',
      ));

  testWidgets('no card and no route on the map without a selection', (tester) async {
    await pumpHome(tester);
    expect(card, findsNothing);
    expect(tester.widget<LiveMap>(find.byType(LiveMap)).trip, isNull);
  });

  testWidgets('shows the selected route on the card and the map', (tester) async {
    await pumpHome(tester, trip: sampleTrip());
    await tester.pumpAndSettle();

    expect(card, findsOneWidget);
    expect(find.text('01K → 13C'), findsOneWidget);
    expect(find.text('Board at Your location → Alight at IT Park'), findsOneWidget);
    expect(find.text('₱28.00 · 25 min · 1 transfer'), findsOneWidget);
    expect(tester.widget<LiveMap>(find.byType(LiveMap)).trip!.markers, isNotEmpty);
  });

  testWidgets('the ✕ cancels it, and the card slides away', (tester) async {
    var cancelled = 0;
    await pumpHome(tester, trip: sampleTrip(), onCancel: () => cancelled++);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Cancel selected route'));
    expect(cancelled, 1);

    // The dashboard then clears it:
    await pumpHome(tester, onCancel: () => cancelled++);
    await tester.pumpAndSettle();
    expect(card, findsNothing);
    expect(tester.widget<LiveMap>(find.byType(LiveMap)).trip, isNull);
  });

  testWidgets('tapping the card opens the route details', (tester) async {
    await pumpHome(tester, trip: sampleTrip());
    await tester.pumpAndSettle();

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(RouteMapScreen), findsOneWidget);
    // Already the selected route: no second "Select this route" button.
    expect(find.text('Select this route'), findsNothing);
  });
}
