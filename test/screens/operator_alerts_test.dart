import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/transit_alert.dart';
import 'package:smartcommute_app/screens/operator/operator_alerts.dart';
import 'package:smartcommute_app/screens/operator/operator_profile.dart';
import 'package:smartcommute_app/services/alerts_service.dart';
import 'package:smartcommute_app/services/route_services.dart';

import '../support/fake_dio.dart';

final _now = DateTime.utc(2026, 10, 10, 12).toLocal();

String _ago(Duration d) => _now.subtract(d).toUtc().toIso8601String();

Map<String, dynamic> _alert(String id, String title, String severity,
        {String? code, bool resolved = false, Duration age = const Duration(minutes: 10)}) =>
    {
      'id': id,
      'title': title,
      'message': '$title message',
      'severity': severity,
      'route_id': code == null ? null : 'r-$code',
      'route_code': code,
      'is_resolved': resolved,
      'created_at': _ago(age),
      'resolved_at': resolved ? _ago(Duration.zero) : null,
    };

final _alerts = [
  _alert('1', 'Temporary route diversion', 'warning', code: 'J02'),
  _alert('2', 'Heavy traffic near SM City', 'critical',
      code: 'B04', age: const Duration(minutes: 28)),
  _alert('3', 'Normal operations restored', 'info',
      code: 'J01', resolved: true, age: const Duration(days: 1)),
];

final _routes = [
  {'id': 'r-J02', 'code': 'J02', 'name': 'Talamban', 'is_active': true, 'owned': true},
];

const _profile = {
  'id': 'p1',
  'user_id': 'u1',
  'company_name': 'Cebu City Transport Co.',
  'franchise_number': 'FR-2024-001',
  'contact_number': '09171234567',
  'email': 'operator@cebulines.ph',
  'is_verified': true,
};

Future<FakeAdapter> _pump(WidgetTester tester, FakeHandler handler) async {
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final adapter = FakeAdapter((options) async {
    if (options.path == '/operators/me') return jsonBody(_profile);
    if (options.path == '/routes/mine') return jsonBody(_routes);
    return handler(options);
  });
  final dio = fakeDio(adapter);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: OperatorAlerts(
        alertsService: AlertsService(dio),
        routesService: RoutesService(dio),
        now: () => _now,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  test('alert time labels', () {
    final now = DateTime(2026, 10, 10, 12);
    expect(alertTimeLabel(now, now), 'Just now');
    expect(alertTimeLabel(now.subtract(const Duration(minutes: 10)), now), '10 minutes ago');
    expect(alertTimeLabel(now.subtract(const Duration(hours: 3)), now), '3 hours ago');
    expect(alertTimeLabel(DateTime(2026, 10, 9, 16, 20), now), 'Yesterday, 4:20 PM');
    expect(alertTimeLabel(DateTime(2026, 10, 3, 9, 5), now), 'Oct 3, 9:05 AM');
  });

  testWidgets('shows published alerts from GET /alerts/mine', (tester) async {
    await _pump(tester, (options) async => jsonBody(_alerts));

    expect(find.text('Transit Alerts'), findsOneWidget);
    expect(find.text('Cebu City Transport Co.'), findsOneWidget);
    expect(find.text('2 active alerts'), findsOneWidget);
    expect(find.text('Temporary route diversion'), findsOneWidget);
    expect(find.text('Critical'), findsWidgets);
    expect(find.text('J02'), findsOneWidget);
    expect(find.text('10 minutes ago'), findsOneWidget);
    expect(find.text('28 minutes ago'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
    expect(find.text('Mark as resolved'), findsNWidgets(2));
    expect(find.text('Reopen alert'), findsOneWidget);
    expect(find.text('Live notifications'), findsOneWidget);
  });

  testWidgets('publishes an alert for the chosen route and severity', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.method == 'POST') {
        return jsonBody(
          _alert('9', 'Road closure', 'critical', code: 'J02', age: Duration.zero),
          status: 201,
        );
      }
      return jsonBody(<Object>[]);
    });
    expect(find.text('No alerts yet. Alerts you publish will appear here.'), findsOneWidget);

    final publish = find.widgetWithText(FilledButton, 'Publish Alert');
    expect(tester.widget<FilledButton>(publish).onPressed, isNull);

    await tester.enterText(find.byType(TextField).at(0), 'Road closure');
    await tester.enterText(find.byType(TextField).at(1), 'Use Mango Avenue.');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Critical'));
    await tester.tap(find.text('All routes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('J02 – Talamban').last);
    await tester.pumpAndSettle();

    await tester.tap(publish);
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/alerts');
    expect(post.data, {
      'title': 'Road closure',
      'message': 'Use Mango Avenue.',
      'severity': 'critical',
      'route_id': 'r-J02',
    });
    expect(find.text('1 active alert'), findsOneWidget);
    expect(find.text('Road closure'), findsOneWidget);
    // The form is cleared for the next alert.
    expect(tester.widget<TextField>(find.byType(TextField).at(0)).controller!.text, '');
  });

  testWidgets('shows the backend error when publishing fails', (tester) async {
    await _pump(tester, (options) async {
      if (options.method == 'POST') {
        return jsonBody({'detail': 'You can only post alerts for routes you run.'}, status: 403);
      }
      return jsonBody(<Object>[]);
    });

    await tester.enterText(find.byType(TextField).at(0), 'T');
    await tester.enterText(find.byType(TextField).at(1), 'M');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Publish Alert'));
    await tester.pumpAndSettle();

    expect(find.text('You can only post alerts for routes you run.'), findsOneWidget);
  });

  testWidgets('mark as resolved moves the alert below active ones', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.method == 'PATCH') {
        return jsonBody(_alert('1', 'Temporary route diversion', 'warning',
            code: 'J02', resolved: true));
      }
      return jsonBody(_alerts);
    });

    await tester.tap(find.text('Mark as resolved').first);
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/alerts/1/resolved');
    expect(patch.data, {'is_resolved': true});
    expect(find.text('1 active alert'), findsOneWidget);
    expect(find.text('Reopen alert'), findsNWidgets(2));
  });

  testWidgets('deleting an alert removes it', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.method == 'DELETE') return jsonBody({'message': 'Alert deleted'});
      return jsonBody(_alerts);
    });

    await tester.tap(find.byTooltip('Delete alert').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'DELETE').path, '/alerts/2');
    expect(find.text('Heavy traffic near SM City'), findsNothing);
  });

  testWidgets('profile shows the operator details from GET /operators/me', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = FakeAdapter((options) async => jsonBody(_profile));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OperatorProfileScreen(service: AlertsService(fakeDio(adapter)))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Operator Profile'), findsOneWidget);
    expect(find.text('CC'), findsOneWidget);
    expect(find.text('Cebu City Transport Co.'), findsNWidgets(3));
    expect(find.text('operator@cebulines.ph'), findsOneWidget);
    expect(find.text('Verified Operator'), findsOneWidget);
    expect(find.text('FR-2024-001'), findsOneWidget);
    expect(find.text('09171234567'), findsOneWidget);
  });

  testWidgets('operator without a profile can set one up', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var created = false;
    final adapter = FakeAdapter((options) async {
      if (options.method == 'POST') {
        created = true;
        return jsonBody('p1');
      }
      return created
          ? jsonBody(_profile)
          : jsonBody({'detail': 'Operator profile not found'}, status: 404);
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: OperatorProfileScreen(service: AlertsService(fakeDio(adapter)))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Set up your company profile'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Cebu City Transport Co.');
    await tester.enterText(find.byType(TextField).at(2), '09171234567');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save Profile'));
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/operators');
    expect(post.data, {
      'company_name': 'Cebu City Transport Co.',
      'franchise_number': null,
      'contact_number': '09171234567',
    });
    expect(find.text('Verified Operator'), findsOneWidget);
  });
}
