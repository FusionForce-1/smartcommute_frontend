import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/transport_model.dart';
import 'package:smartcommute_app/models/vehicles.dart';
import 'package:smartcommute_app/providers/profile_provider.dart';
import 'package:smartcommute_app/services/profile_service.dart';
import 'package:smartcommute_app/widgets/commuter/review_ride_sheet.dart';

import '../support/fake_dio.dart';

void main() {
  const route = TransportRoute(
    id: 'r1', name: 'Carbon - Banawa', code: '07B',
    geometry: [LatLng(10.29, 123.89), LatLng(10.30, 123.88)], stops: [], isActive: true,
  );
  const jeeps = [
    Vehicle(id: 'v1', plateNumber: 'ABC-123', routeId: 'r1', status: 'active'),
    Vehicle(id: 'v2', plateNumber: 'XYZ-999', routeId: 'other', status: 'active'),
  ];

  Future<(FakeAdapter, ProfileProvider)> open(WidgetTester tester) async {
    final adapter = FakeAdapter((options) async {
      if (options.path == '/reviews' && options.method == 'POST') {
        return jsonBody({
          'id': 'rev1', 'route_id': 'r1', 'route_code': '07B', 'vehicle_id': 'v1', 'plate_number': 'ABC-123',
          'rating': 4, 'tags': ['safe_driving'], 'comment': 'Smooth ride', 'created_at': '2026-10-19T06:00:00',
        }, status: 201);
      }
      return jsonBody({'detail': 'not found'}, status: 404);
    });
    final profile = ProfileProvider(service: ProfileService(fakeDio(adapter)), isGuest: false);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showReviewRideSheet(context, profile: profile, routes: const [route], vehicles: jeeps),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return (adapter, profile);
  }

  testWidgets('sends route, jeep, stars, tags and comment', (tester) async {
    final (adapter, profile) = await open(tester);
    FilledButton submit() => tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Submit review'));
    expect(submit().onPressed, isNull, reason: 'needs a jeep and stars first');

    // Only jeeps on the chosen route are offered.
    await tester.tap(find.text('Jeep (plate number)'));
    await tester.pumpAndSettle();
    expect(find.text('XYZ-999'), findsNothing);
    await tester.tap(find.text('ABC-123').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('4 stars'));
    await tester.tap(find.text('Safe driving'));
    await tester.enterText(find.widgetWithText(TextField, 'Comment (optional)'), 'Smooth ride');
    await tester.pump();
    expect(find.text('Good'), findsOneWidget);
    expect(submit().onPressed, isNotNull);

    await tester.ensureVisible(find.text('Submit review'));
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();

    final sent = adapter.requests.singleWhere((r) => r.path == '/reviews');
    expect(sent.data, {'route_id': 'r1', 'vehicle_id': 'v1', 'rating': 4, 'tags': ['safe_driving'], 'comment': 'Smooth ride'});
    expect(profile.reviews.single.plateNumber, 'ABC-123');
    expect(find.text('Rate your ride'), findsNothing, reason: 'sheet closes after sending');
  });

  testWidgets('"Not sure of the plate" sends no vehicle', (tester) async {
    final (adapter, _) = await open(tester);
    await tester.tap(find.text('Jeep (plate number)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not sure of the plate').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('5 stars'));
    await tester.pump();
    await tester.ensureVisible(find.text('Submit review'));
    await tester.tap(find.text('Submit review'));
    await tester.pumpAndSettle();
    final data = adapter.requests.singleWhere((r) => r.path == '/reviews').data as Map;
    expect(data.containsKey('vehicle_id'), isFalse);
    expect(data['rating'], 5);
  });

  test('server error comes back as a message', () async {
    final adapter = FakeAdapter((_) async => jsonBody({'detail': 'You already reviewed this ride.'}, status: 409));
    final profile = ProfileProvider(service: ProfileService(fakeDio(adapter)), isGuest: false);
    final error = await profile.submitReview(routeId: 'r1', rating: 3, tags: const []);
    expect(error, contains('already reviewed'));
    expect(profile.reviews, isEmpty);
    expect(Dio, isNotNull);
  });
}
