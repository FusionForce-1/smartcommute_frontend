import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/providers/trip_plan_provider.dart';
import 'package:smartcommute_app/screens/commuter/trip_planner_screen.dart';
import 'package:smartcommute_app/services/location_source.dart';
import 'package:smartcommute_app/services/trip_plan_service.dart';
import 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart';

import '../support/fake_dio.dart';
import '../support/fake_location_source.dart';
import '../support/trip_plan_fixtures.dart';

// FilledButton.icon may be a private subclass, so match by base type.
Finder findRoutesButton() => find.ancestor(
      of: find.text('Find routes'),
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    );

bool isEnabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(findRoutesButton()).onPressed != null;

Future<TripPlanProvider> pumpPlanner(
  WidgetTester tester, {
  FakeLocationSource? location,
}) async {
  final provider = TripPlanProvider(
    service: TripPlanService(
      fakeDio(FakeAdapter((_) async => jsonBody(sampleResponse()))),
    ),
    locationSource: location ?? FakeLocationSource(result: const LatLng(10.31, 123.89)),
  );
  await tester.pumpWidget(MaterialApp(
    home: ChangeNotifierProvider<TripPlanProvider>.value(
      value: provider,
      child: const TripPlannerScreen(stops: []),
    ),
  ));
  await tester.pumpAndSettle();
  return provider;
}

void main() {
  testWidgets('locates origin on open and plans a trip end to end', (tester) async {
    final provider = await pumpPlanner(tester);

    expect(find.text('10.3100, 123.8900'), findsOneWidget);
    expect(isEnabled(tester), isFalse);

    provider.setDestination(const LatLng(10.33, 123.905), 'IT Park');
    await tester.pump();
    expect(find.text('To: IT Park'), findsOneWidget);

    expect(isEnabled(tester), isTrue);
    await tester.tap(findRoutesButton());
    await tester.pumpAndSettle();
    expect(find.text('01K → 13C'), findsOneWidget);
    expect(find.text('₱28.00'), findsOneWidget);

    await tester.tap(find.text('01K → 13C'));
    await tester.pumpAndSettle();
    expect(find.byType(FareBreakdownSheet), findsOneWidget);
    expect(provider.selectedOption, isNotNull);
  });

  testWidgets('shows the location error and keeps Find routes disabled', (tester) async {
    final provider = await pumpPlanner(
      tester,
      location: FakeLocationSource(failure: LocationFailure.denied),
    );
    provider.setDestination(const LatLng(10.33, 123.905), 'IT Park');
    await tester.pump();

    expect(find.text('Location permission is needed to plan a trip.'), findsOneWidget);
    expect(isEnabled(tester), isFalse);
  });

  testWidgets('hides Open settings where the platform cannot open them (web)', (tester) async {
    await pumpPlanner(
      tester,
      location: FakeLocationSource(
        failure: LocationFailure.denied,
        canOpenSettings: false,
      ),
    );

    expect(find.text('Location permission is needed to plan a trip.'), findsOneWidget);
    expect(find.byTooltip('Open settings'), findsNothing);
    expect(find.byTooltip('Refresh location'), findsOneWidget);
  });

  testWidgets('shows Open settings on platforms that support it', (tester) async {
    await pumpPlanner(
      tester,
      location: FakeLocationSource(failure: LocationFailure.denied),
    );

    expect(find.byTooltip('Open settings'), findsOneWidget);
  });

  testWidgets('empty stop list shows a helpful message in the search sheet', (tester) async {
    await pumpPlanner(tester);

    await tester.tap(find.text('To: Choose a destination'));
    await tester.pumpAndSettle();

    expect(find.text('No stops available yet. Try "Pick on map".'), findsOneWidget);
  });
}
