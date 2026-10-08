import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/fleet.dart';
import 'package:smartcommute_app/screens/operator/operator_dashboard.dart';

import '../support/fake_dio.dart';

String _iso(DateTime t) => t.toUtc().toIso8601String().replaceFirst('Z', '');

Map<String, dynamic> _vehicle(
  String id,
  String plate,
  String routeId, {
  String status = 'active',
  bool suspended = false,
  String routeStatus = 'active',
  String? crowd,
  DateTime? ping,
}) =>
    {
      'vehicle_id': id,
      'plate_number': plate,
      'route_id': routeId,
      'status': status,
      'suspended': suspended,
      'crowd_level': crowd,
      'last_position': ping == null
          ? null
          : {'lat': 10.3, 'lng': 123.9, 'timestamp': _iso(ping)},
      'route_status': routeStatus,
    };

void main() {
  group('fleet models', () {
    test('timestamps without a zone are read as UTC', () {
      final t = parseUtc('2026-10-07T02:00:00');
      expect(t!.toUtc(), DateTime.utc(2026, 10, 7, 2));
      expect(parseUtc('2026-10-07T02:00:00+00:00')!.toUtc(), DateTime.utc(2026, 10, 7, 2));
    });

    test('timeAgo', () {
      final now = DateTime(2026, 10, 7, 12);
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now), 'Just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 2)), now), '2 min ago');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now), '3 hr ago');
      expect(timeAgo(now.subtract(const Duration(days: 1)), now), '1 day ago');
    });
  });

  testWidgets('dashboard shows live fleet, routes, drivers and announcements',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final adapter = FakeAdapter((options) async {
      switch (options.path) {
        case '/fleet':
          return jsonBody([
            _vehicle('v1', 'ABC-1234', 'r1', crowd: 'low',
                ping: now.subtract(const Duration(minutes: 2))),
            _vehicle('v2', 'XYZ-5678', 'r2', routeStatus: 'congested',
                ping: now.subtract(const Duration(minutes: 5))),
            _vehicle('v3', 'JKL-9012', 'r1', status: 'maintenance'),
          ]);
        case '/routes':
          return jsonBody([
            {'id': 'r1', 'code': 'J02', 'name': 'Talamban'},
            {'id': 'r2', 'code': 'B04', 'name': 'SM City'},
          ]);
        case '/drivers':
          return jsonBody([{}, {}, {}, {}]
              .asMap()
              .entries
              .map((e) => {
                    'id': 'd${e.key}',
                    'license_number': 'N01-23-00000${e.key}',
                    'expiration_date': '2030-01-01',
                  })
              .toList());
        case '/announcements':
          return jsonBody([
            {
              'id': 'a1',
              'title': 'Road closure',
              'message': 'Osmeña Blvd closed until 6 PM.',
              'target_role': null,
              'created_by': 'admin',
              'created_at': _iso(now.subtract(const Duration(hours: 3))),
              'expires_at': _iso(now.add(const Duration(days: 1))),
            },
          ]);
      }
      return jsonBody({'detail': 'not found'}, status: 404);
    });

    await tester.pumpWidget(MaterialApp(home: OperatorDashboard(dio: fakeDio(adapter))));
    await tester.pumpAndSettle();

    // Summary cards: 2 of 3 vehicles active, on 2 routes; 4 drivers; 2/3 pinged.
    expect(find.text('Active Vehicles'), findsOneWidget);
    expect(find.text('of 3 registered'), findsOneWidget);
    expect(find.text('of 2 assigned'), findsOneWidget);
    expect(find.text('Registered Drivers'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('Total Rides'), findsNothing);
    expect(find.text('Revenue'), findsNothing);

    // Fleet table.
    expect(find.text('ABC-1234'), findsOneWidget);
    expect(find.text('J02 – Talamban'), findsNWidgets(2));
    expect(find.text('B04 – SM City'), findsOneWidget);
    expect(find.text('On-Route'), findsOneWidget);
    expect(find.text('Delayed'), findsOneWidget);
    expect(find.text('Maintenance'), findsOneWidget);
    expect(find.text('2 min ago'), findsOneWidget);
    expect(find.text('Never'), findsOneWidget);
    expect(find.text('Low'), findsOneWidget);

    // Announcements.
    expect(find.text('Road closure'), findsOneWidget);
    expect(find.text('3 hr ago'), findsOneWidget);

    // Mock rows are gone.
    expect(find.text('VH-001'), findsNothing);
    expect(find.text('Juan dela Cruz'), findsNothing);
  });

  testWidgets('dashboard shows the backend error when the fleet fails',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final adapter = FakeAdapter((options) async {
      if (options.path == '/fleet') {
        return jsonBody({'detail': 'Account pending administrator verification'},
            status: 403);
      }
      return jsonBody([]);
    });

    await tester.pumpWidget(MaterialApp(home: OperatorDashboard(dio: fakeDio(adapter))));
    await tester.pumpAndSettle();

    expect(find.text('Account pending administrator verification'), findsOneWidget);
    expect(find.text('Fleet data is unavailable.'), findsOneWidget);
    expect(find.text('No active announcements.'), findsOneWidget);
  });
}
