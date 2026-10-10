import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/screens/operator/operator_routes.dart';
import 'package:smartcommute_app/services/route_services.dart';

import '../support/fake_dio.dart';

Map<String, dynamic> _route(String id, String code, String name, String from,
        String to, {bool active = true, int stops = 0, num? fare, int vehicles = 0,
        bool owned = true}) =>
    {
      'id': id,
      'code': code,
      'name': name,
      'terminal_a': from,
      'terminal_b': to,
      'base_fare': fare,
      'stop_count': stops,
      'vehicle_count': vehicles,
      'is_active': active,
      'owned': owned,
    };

final _routes = [
  _route('1', 'B04', 'SM City – IT Park', 'SM City Cebu', 'Cebu IT Park',
      stops: 9, fare: 18, vehicles: 4),
  _route('2', 'J04', 'Mabolo – Ayala', 'Mabolo', 'Ayala Center Cebu',
      active: false, stops: 7, fare: 13),
  _route('3', '07B', 'Guadalupe - Carbon', 'Guadalupe', 'Carbon',
      stops: 2, fare: 17, vehicles: 3, owned: false),
];

Future<FakeAdapter> _pump(WidgetTester tester, FakeHandler handler) async {
  tester.view.physicalSize = const Size(1400, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final adapter = FakeAdapter(handler);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: OperatorRoutes(service: RoutesService(fakeDio(adapter))),
    ),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('shows routes and totals fetched from GET /routes/mine', (tester) async {
    await _pump(tester, (options) async {
      if (options.path == '/operators/me') {
        return jsonBody({'company_name': 'Cebu City Transport Co.'});
      }
      return jsonBody(_routes);
    });

    expect(find.text('Route Management'), findsOneWidget);
    expect(find.text('Cebu City Transport Co.'), findsOneWidget);
    expect(find.text('SM City – IT Park'), findsOneWidget);
    expect(find.text('Ayala Center Cebu'), findsOneWidget);
    expect(find.text('₱18'), findsOneWidget);
    expect(find.text('Inactive'), findsOneWidget);
    expect(find.text('Pause Route'), findsOneWidget);
    expect(find.text('Activate Route'), findsOneWidget);
    // Shared routes can't be changed by this operator.
    expect(find.text('Shared'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    // Total routes, active routes, assigned vehicles.
    expect(find.text('3'), findsWidgets);
    expect(find.text('2'), findsWidgets);
    expect(find.text('7'), findsWidgets);
  });

  testWidgets('Add Route opens the form and creates an inactive route', (tester) async {
    var routes = [..._routes];
    final adapter = await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      if (options.method == 'POST') {
        routes = [
          ...routes,
          _route('4', 'J05', 'Talamban – Pier 1', 'Talamban', 'Pier 1',
              active: false, fare: 13),
        ];
        return jsonBody({'id': '4', 'message': 'Route created'}, status: 201);
      }
      return jsonBody(routes);
    });

    await tester.tap(find.text('Add Route'));
    await tester.pumpAndSettle();
    expect(find.text('Create New Route'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    final create = find.widgetWithText(FilledButton, 'Create Route');
    expect(tester.widget<FilledButton>(create).onPressed, isNull);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'j05');
    await tester.enterText(fields.at(1), 'Talamban – Pier 1');
    await tester.enterText(fields.at(2), 'Talamban');
    await tester.enterText(fields.at(3), 'Pier 1');
    await tester.enterText(fields.at(4), '13');
    await tester.pump();
    expect(tester.widget<FilledButton>(create).onPressed, isNotNull);

    await tester.tap(create);
    await tester.pumpAndSettle();

    final post = adapter.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/routes');
    expect(jsonDecode(jsonEncode(post.data)), {
      'code': 'J05',
      'name': 'Talamban – Pier 1',
      'terminal_a': 'Talamban',
      'terminal_b': 'Pier 1',
      'fare_matrix': {'base': 13.0},
    });
    expect(find.text('Create New Route'), findsNothing);
    expect(find.text('Pier 1'), findsOneWidget);
  });

  testWidgets('shows the backend error when creating fails', (tester) async {
    await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      if (options.method == 'POST') {
        return jsonBody({'detail': 'Route code B04 is already in use.'}, status: 409);
      }
      return jsonBody(_routes);
    });

    await tester.tap(find.text('Add Route'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'B04');
    await tester.enterText(fields.at(1), 'Dup');
    await tester.enterText(fields.at(2), 'A');
    await tester.enterText(fields.at(3), 'B');
    await tester.enterText(fields.at(4), '10');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Route'));
    await tester.pumpAndSettle();

    expect(find.text('Route code B04 is already in use.'), findsOneWidget);
    expect(find.text('Create New Route'), findsOneWidget);
  });

  testWidgets('Activate Route sends PATCH /routes/{id}/active', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      if (options.method == 'PATCH') return jsonBody({'id': '2', 'is_active': true});
      return jsonBody(_routes);
    });

    await tester.tap(find.text('Activate Route'));
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/routes/2/active');
    expect(patch.data, {'is_active': true});
    expect(find.text('Activate Route'), findsNothing);
    expect(find.text('Pause Route'), findsNWidgets(2));
  });

  testWidgets('pausing a route with vehicles asks first', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      if (options.method == 'PATCH') return jsonBody({'id': '1', 'is_active': false});
      return jsonBody(_routes);
    });

    await tester.tap(find.widgetWithText(OutlinedButton, 'Pause Route'));
    await tester.pumpAndSettle();
    expect(find.text('Pause route?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Pause Route'));
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/routes/1/active');
    expect(patch.data, {'is_active': false});
    expect(find.text('Activate Route'), findsNWidgets(2));
  });

  testWidgets('deleting a route removes its card', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      if (options.method == 'DELETE') return jsonBody({'message': 'Route deleted'});
      return jsonBody(_routes);
    });

    await tester.tap(find.byIcon(Icons.delete_outline).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(adapter.requests.singleWhere((r) => r.method == 'DELETE').path, '/routes/2');
    expect(find.text('Mabolo – Ayala'), findsNothing);
  });

  testWidgets('shows a retry when the routes fail to load', (tester) async {
    await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      return jsonBody({'detail': 'Your operator account has not been verified by an admin yet.'},
          status: 403);
    });

    expect(find.text('Your operator account has not been verified by an admin yet.'),
        findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
