// The Selected Route card says where the commuter is in the trip.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/selected_trip.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/services/trip_eta.dart';
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

  Future<void> show(WidgetTester tester, TripProgressState? state, {TripEta? eta, String? plate}) =>
      tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SelectedTripCard(
              trip: trip, progress: state, eta: eta, boardedPlate: plate, onCancel: () {}, onOpen: () {}),
        ),
      ));

  final arrive = DateTime(2026, 11, 16, 8, 21);   // local time
  Finder text(String s) => find.text(s, findRichText: true);

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

  testWidgets('walking to the stop: the walk, the next live jeep and the arrival time', (tester) async {
    await show(tester, at(TripPhase.toBoard),
        eta: TripEta(minutes: 21, arriveAt: arrive, walkMin: 3, waitMin: 2, jeepId: 'j1', jeepInMin: 5));
    expect(find.text('Walk 3 min to ${leg.boardLabel}, then board the 01K'), findsOneWidget);
    expect(find.text('Next 01K reaches the stop in 5 min'), findsOneWidget);
    expect(find.text('₱28.00 · Arrive 8:21 AM · 21 min · 1 transfer'), findsOneWidget);
    expect(find.byKey(const Key('onBoardBanner')), findsNothing);
  });

  testWidgets('waiting at the stop, with or without a live jeep', (tester) async {
    await show(tester, at(TripPhase.toBoard), eta: TripEta(minutes: 26, arriveAt: arrive, walkMin: 0, waitMin: 10));
    expect(find.text('At ${leg.boardLabel} · wait for the 01K'), findsOneWidget);
    expect(find.text('No live 01K yet · usual wait about 10 min'), findsOneWidget);

    await show(tester, at(TripPhase.toBoard),
        eta: TripEta(minutes: 16, arriveAt: arrive, walkMin: 0, waitMin: 0, jeepId: 'j1', jeepInMin: 0));
    expect(find.text('A 01K is at the stop now'), findsOneWidget);
  });

  testWidgets("on board: says it's the jeep they waited for, and the ride left", (tester) async {
    await show(tester, at(TripPhase.riding), eta: TripEta(minutes: 11, arriveAt: arrive, rideLeftMin: 9), plate: 'GAB 1234');
    expect(find.byKey(const Key('onBoardBanner')), findsOneWidget);
    expect(text("You're on the 01K you were waiting for · GAB 1234"), findsOneWidget);
    expect(find.text('On the jeep · 2.3 km to ${leg.alightLabel} · about 9 min'), findsOneWidget);
    expect(find.byKey(const Key('tripWaitLine')), findsNothing);
  });

  testWidgets('no on-board banner without a matched jeep, or before boarding', (tester) async {
    await show(tester, at(TripPhase.riding), eta: TripEta(minutes: 11, arriveAt: arrive, rideLeftMin: 9));
    expect(find.byKey(const Key('onBoardBanner')), findsNothing);
    await show(tester, at(TripPhase.toBoard), eta: TripEta(minutes: 21, arriveAt: arrive, walkMin: 3, waitMin: 2), plate: 'GAB 1234');
    expect(find.byKey(const Key('onBoardBanner')), findsNothing);
  });
}
