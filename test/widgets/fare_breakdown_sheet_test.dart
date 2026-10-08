import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart';

import '../support/trip_plan_fixtures.dart';

void main() {
  testWidgets('shows total, one row per leg, and the estimate note', (tester) async {
    final option = TripPlanResponse.fromJson(sampleResponse()).options.single;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FareBreakdownSheet(option: option))),
    );

    expect(find.text('₱28.00'), findsOneWidget);
    expect(find.text('25 min · 1 transfer'), findsOneWidget);
    expect(find.text('01K'), findsOneWidget);
    expect(find.text('13C'), findsOneWidget);
    expect(find.text('Board at Your location → Alight at Colon'), findsOneWidget);
    expect(find.text('Board at Colon → Alight at IT Park'), findsOneWidget);
    expect(find.text('₱13.00'), findsOneWidget);
    expect(find.text('₱15.00'), findsOneWidget);
    expect(find.text('Estimated fare — actual fare may vary.'), findsOneWidget);
  });

  testWidgets('stub leg with placeholder alight stop reads "Your destination"', (tester) async {
    // Mao ni ang i-return sa backend karon: board ug alight parehas placeholder.
    final json = sampleResponse();
    final leg = ((json['options'] as List).first['legs'] as List).first as Map;
    leg['alight_stop'] = stopJson('0', 'Origin', 0, 0);
    final option = TripPlanResponse.fromJson(json).options.single;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: FareBreakdownSheet(option: option))),
    );

    expect(find.text('Board at Your location → Alight at Your destination'), findsOneWidget);
  });

  testWidgets('showFareBreakdownSheet opens it as a bottom sheet', (tester) async {
    final option = TripPlanResponse.fromJson(sampleResponse()).options.single;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showFareBreakdownSheet(context, option),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(FareBreakdownSheet), findsOneWidget);
  });
}
