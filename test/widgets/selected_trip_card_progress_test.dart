// The Selected Route card says where the commuter is in the trip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/selected_trip.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/services/trip_progress.dart';
import 'package:smartcommute_app/widgets/commuter/selected_trip_card.dart';

import '../support/trip_plan_fixtures.dart';

void main() {
  final trip = SelectedTrip(
    option: TripPlanResponse.fromJson(sampleResponse()).options.first,
    from: 'Your location',
    to: 'IT Park',
    routesById: const {},
  );
  final leg = trip.option.legs.first;

  Future<void> show(WidgetTester tester, TripProgressState? state) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SelectedTripCard(trip: trip, progress: state, onCancel: () {}, onOpen: () {})),
      ));

  TripProgressState at(TripPhase phase, {double remaining = 2300}) =>
      TripProgressState(phase: phase, legIndex: 0, alongM: 100, remainingM: remaining, speedKmh: 20);

  testWidgets('no status before the first GPS fix', (tester) async {
    await show(tester, null);
    expect(find.byKey(const Key('tripProgressStatus')), findsNothing);
  });

  testWidgets('walking, riding, getting off and arrived', (tester) async {
    await show(tester, at(TripPhase.toBoard));
    expect(find.textContaining('Walk to ${leg.boardLabel}'), findsOneWidget);
    await show(tester, at(TripPhase.riding));
    expect(find.text('On the jeep · 2.3 km to ${leg.alightLabel}'), findsOneWidget);
    await show(tester, at(TripPhase.alightSoon, remaining: 200));
    expect(find.text('Get off soon at ${leg.alightLabel}'), findsOneWidget);
    await show(tester, at(TripPhase.arrived, remaining: 0));
    expect(find.text("You've arrived"), findsOneWidget);
  });
}
