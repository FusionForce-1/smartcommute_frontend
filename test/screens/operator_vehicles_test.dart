import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/screens/operator/operator_vehicles.dart';
import 'package:smartcommute_app/services/drivers_service.dart';

import '../support/fake_dio.dart';

Map<String, dynamic> _driver(String id, String code, String first, String last,
        String license, String expiry, String status) =>
    {
      'id': id,
      'driver_code': code,
      'operator_id': 'op1',
      'full_name': '$last, $first',
      'last_name': last,
      'first_name': first,
      'license_number': license,
      'expiration_date': expiry,
      'status': status,
      'created_at': '2026-10-01T00:00:00Z',
    };

Future<FakeAdapter> _pump(WidgetTester tester, FakeHandler handler) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final adapter = FakeAdapter(handler);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: OperatorVehicles(service: DriversService(fakeDio(adapter))),
    ),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  testWidgets('shows the roster fetched from GET /drivers', (tester) async {
    await _pump(tester, (options) async {
      if (options.path == '/operators/me') {
        return jsonBody({'company_name': 'Cebu City Transport Co.'});
      }
      return jsonBody([
        _driver('1', 'DRV-001', 'JUAN', 'DELA CRUZ', 'N01-23-456789', '2028-12-18', 'active'),
        _driver('2', 'DRV-002', 'PEDRO', 'SANTOS', 'N02-24-317642', '2027-08-04', 'off_duty'),
      ]);
    });

    expect(find.text('Driver Management'), findsOneWidget);
    expect(find.text('Cebu City Transport Co.'), findsOneWidget);
    expect(find.text('2 registered drivers'), findsOneWidget);
    expect(find.text('Licenses verified'), findsOneWidget);
    expect(find.text('Juan dela Cruz'), findsOneWidget);
    expect(find.text('Pedro Santos'), findsOneWidget);
    expect(find.text('N01-23-456789'), findsOneWidget);
    expect(find.text('Dec 18, 2028'), findsOneWidget);
    expect(find.text('Aug 04, 2027'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Off Duty'), findsOneWidget);
    expect(find.text('Password'), findsNWidgets(2));
  });

  testWidgets('clicking a driver shows every stored field', (tester) async {
    await _pump(tester, (options) async {
      if (options.path == '/operators/me') return jsonBody({'company_name': 'X'});
      return jsonBody([
        {
          ..._driver('1', 'DRV-001', 'JUAN', 'DELA CRUZ', 'N01-23-456789',
              '2028-12-18', 'active'),
          'sex': 'M',
          'date_of_birth': '1990-05-04',
          'nationality': 'PHL',
          'address': '123 Colon St, Cebu City',
          'height_m': 1.7,
          'weight_kg': 65,
          'blood_type': 'O+',
          'dl_codes': ['A', 'B'],
          'serial_number': 'S123',
        },
      ]);
    });

    await tester.tap(find.text('Juan dela Cruz'));
    await tester.pumpAndSettle();

    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('DELA CRUZ, JUAN'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('May 04, 1990'), findsOneWidget);
    expect(find.text('123 Colon St, Cebu City'), findsOneWidget);
    expect(find.text('1.7 m'), findsOneWidget);
    expect(find.text('65 kg'), findsOneWidget);
    expect(find.text('A, B'), findsOneWidget);
    expect(find.text('S123'), findsOneWidget);
    // Fields the license scan didn't capture.
    expect(find.text('Not recorded'), findsWidgets);
  });

  testWidgets('Add Driver opens the license upload dialog', (tester) async {
    await _pump(tester, (_) async => jsonBody([]));

    await tester.tap(find.text('Add Driver'));
    await tester.pumpAndSettle();

    expect(find.text('Add New Driver'), findsOneWidget);
    expect(find.text('Auto-scan enabled'), findsOneWidget);
    expect(find.text('Front of license'), findsOneWidget);
    expect(find.text('Back of license'), findsOneWidget);
    expect(find.text('Choose image'), findsNWidgets(2));

    // Disabled until both sides are scanned.
    final submit = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Add Driver').last,
    );
    expect(submit.onPressed, isNull);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add New Driver'), findsNothing);
  });

  testWidgets('shows the backend error with a retry button', (tester) async {
    await _pump(tester, (_) async => jsonBody({'detail': 'Operator profile not found'}, status: 404));

    expect(find.text('Operator profile not found'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
