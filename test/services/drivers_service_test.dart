import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/models/driver.dart';
import 'package:smartcommute_app/services/drivers_service.dart';

import '../support/fake_dio.dart';

Map<String, dynamic> driverJson({
  String id = 'd1',
  String status = 'active',
  String expiry = '2028-12-18',
  Map<String, dynamic>? account,
}) =>
    {
      'id': id,
      'driver_code': 'DRV-001',
      'operator_id': 'op1',
      'full_name': 'DELA CRUZ, JUAN',
      'last_name': 'DELA CRUZ',
      'first_name': 'JUAN',
      'middle_name': null,
      'license_number': 'N01-23-456789',
      'expiration_date': expiry,
      'status': status,
      'created_at': '2026-10-01T00:00:00Z',
      if (account != null) 'account': account,
    };

void main() {
  test('GET /drivers parses the roster', () async {
    final adapter = FakeAdapter((_) async => jsonBody([driverJson()]));
    final drivers = await DriversService(fakeDio(adapter)).getDrivers();

    expect(adapter.requests.single.path, '/drivers');
    final d = drivers.single;
    expect(d.displayName, 'Juan dela Cruz');
    expect(d.driverCode, 'DRV-001');
    expect(d.licenseNumber, 'N01-23-456789');
    expect(d.expirationDate, DateTime(2028, 12, 18));
    expect(d.isActive, isTrue);
    expect(d.email, isNull);
  });

  test('license expiry is compared by date', () {
    final d = Driver.fromJson(driverJson(expiry: '2026-10-07'));
    expect(d.isLicenseExpired(DateTime(2026, 10, 7, 23)), isFalse);
    expect(d.isLicenseExpired(DateTime(2026, 10, 8)), isTrue);
  });

  test('scan-license uploads both sides as PNG/JPEG multipart', () async {
    final adapter = FakeAdapter((_) async => jsonBody({
          'front': {'first_name': 'JUAN', 'license_number': null},
          'back': {'serial_number': 'S123'},
          'missing_fields': ['license_number'],
          'scan_complete': false,
        }));
    final scan = await DriversService(fakeDio(adapter)).scanLicense(
      front: LicenseImage(name: 'front.PNG', bytes: Uint8List(3)),
      back: LicenseImage(name: 'back.jpg', bytes: Uint8List(3)),
    );

    final request = adapter.requests.single;
    expect(request.path, '/drivers/scan-license');
    final files = (request.data as FormData).files;
    expect(files.map((f) => f.key), ['front', 'back']);
    expect(files[0].value.contentType.toString(), 'image/png');
    expect(files[1].value.contentType.toString(), 'image/jpeg');
    expect(scan.firstName, 'JUAN');
    expect(scan.missingFields, ['license_number']);
  });

  test('create body merges scan with reviewed fields', () {
    final scan = LicenseScan.fromJson({
      'front': {'first_name': 'JUAN', 'sex': 'M', 'dl_codes': ['A', 'B']},
      'back': {'serial_number': 'S123'},
      'missing_fields': [],
      'scan_complete': true,
    });
    final body = scan.toCreateJson(
      firstName: ' Juan ',
      lastName: 'Dela Cruz',
      middleName: '',
      licenseNumber: 'n01-23-456789',
      expirationDate: DateTime(2028, 12, 18),
    );
    expect(body['first_name'], 'Juan');
    expect(body['middle_name'], isNull);
    expect(body['license_number'], 'N01-23-456789');
    expect(body['expiration_date'], '2028-12-18');
    expect(body['sex'], 'M');
    expect(body['dl_codes'], ['A', 'B']);
    expect(body['serial_number'], 'S123');
  });

  test('POST /drivers returns generated credentials when present', () async {
    final adapter = FakeAdapter((_) async => jsonBody(
          driverJson(account: {
            'user_id': 'u1',
            'email': 'juan.delacruz@smartcommute.ph',
            'password': 'SC@Juan7hQ4mX9p',
          }),
          status: 201,
        ));
    final created = await DriversService(fakeDio(adapter)).addDriver({});

    expect(adapter.requests.single.method, 'POST');
    expect(created.account?.password, 'SC@Juan7hQ4mX9p');
    expect(created.driver.email, 'juan.delacruz@smartcommute.ph');
  });

  test('PATCH /drivers/{id}/account sends the new password', () async {
    final adapter = FakeAdapter(
        (_) async => jsonBody({'user_id': 'u1', 'email': 'juan@x.ph'}));
    final email =
        await DriversService(fakeDio(adapter)).updatePassword('d1', 'abc12345');

    final request = adapter.requests.single;
    expect(request.method, 'PATCH');
    expect(request.path, '/drivers/d1/account');
    expect(request.data, {'password': 'abc12345'});
    expect(email, 'juan@x.ph');
  });

  test('error message prefers backend detail', () async {
    final adapter = FakeAdapter((_) async => jsonBody(
          {'detail': 'This license expired on 2020-01-01.'},
          status: 400,
        ));
    try {
      await DriversService(fakeDio(adapter)).addDriver({});
      fail('should throw');
    } catch (e) {
      expect(driverErrorMessage(e, 'x'), 'This license expired on 2020-01-01.');
    }
  });
}
