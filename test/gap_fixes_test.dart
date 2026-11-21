// Gap fix tests
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/transport_model.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/screens/commuter/privacy_security_screen.dart';
import 'package:smartcommute_app/screens/commuter/send_feedback_screen.dart';
import 'package:smartcommute_app/services/api_service.dart';
import 'package:smartcommute_app/services/place_search.dart';
import 'package:smartcommute_app/services/profile_service.dart';
import 'package:smartcommute_app/services/websocket_service.dart';
import 'package:smartcommute_app/utils/password_rule.dart';
import 'package:smartcommute_app/widgets/commuter/crowd_chip.dart';
import 'package:smartcommute_app/widgets/commuter/nearby_vehicle_card.dart';
import 'package:smartcommute_app/widgets/driver/traffic_report_card.dart';
import 'package:smartcommute_app/widgets/fare_breakdown_sheet.dart';

import 'support/fake_dio.dart';
import 'support/trip_plan_fixtures.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

Map<String, dynamic> _tokens() => {
      'access_token': 'a1',
      'refresh_token': 'r1',
      'token_type': 'bearer',
      'role': 'commuter',
      'expires_in': 900,
    };

void main() {
  group('crowd level', () {
    test('live frames carry the crowd percent and the shift flag', () {
      final u = VehicleLiveUpdate.fromJson(
          {'vehicle_id': 'v', 'status': 'en_route', 'lat': 10.3, 'lng': 123.9, 'crowd': 'medium', 'crowd_percent': 55, 'on_shift': true});
      expect(u.crowdPercent, 55);
      expect(u.onShift, isTrue);
      expect(VehicleLiveUpdate.fromJson({'vehicle_id': 'v', 'on_shift': false}).onShift, isFalse);
      expect(VehicleLiveUpdate.fromJson({'vehicle_id': 'v'}).onShift, isNull, reason: 'older servers send no flag');
    });

    test('a crowd-only message keeps the position and updates the crowd', () {
      final moving = VehicleLiveUpdate.fromJson(
          {'vehicle_id': 'v', 'status': 'en_route', 'lat': 10.3, 'lng': 123.9, 'crowd': 'low', 'crowd_percent': 10, 'eta_next_stop': 4});
      final merged = moving.merge(VehicleLiveUpdate.fromJson(
          {'vehicle_id': 'v', 'status': 'en_route', 'crowd': 'high', 'crowd_percent': 90, 'on_shift': true}))!;
      expect(merged.location, const LatLng(10.3, 123.9));
      expect((merged.crowd, merged.crowdPercent, merged.etaNextStop), ('high', 90, 4));
    });

    testWidgets('the chip shows words and an icon, and hides without a value', (tester) async {
      await tester.pumpWidget(_wrap(const Column(children: [
        CrowdChip(level: 'low'),
        CrowdChip(level: 'medium'),
        CrowdChip(level: 'high'),
        CrowdChip(level: null),
      ])));
      expect(find.text('Seats available'), findsOneWidget);
      expect(find.text('Filling up'), findsOneWidget);
      expect(find.text('Nearly full'), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(3));
    });

    testWidgets('nearby cards show the crowd chip', (tester) async {
      await tester.pumpWidget(_wrap(const NearbyVehicleCard(routeCode: '10M', routeName: 'SM – UC', crowd: 'high')));
      expect(find.text('Nearly full'), findsOneWidget);
      await tester.pumpWidget(_wrap(const NearbyVehicleCard(routeCode: '10M', routeName: 'SM – UC')));
      expect(find.byType(CrowdChip), findsNothing);
    });
  });

  group('phone GPS keepalive', () {
    Position fixAt(DateTime t) => Position(
          latitude: 10.3, longitude: 123.9, timestamp: t, accuracy: 5, altitude: 0,
          altitudeAccuracy: 0, heading: 0, headingAccuracy: 0, speed: 0, speedAccuracy: 0);

    test('a fix older than 30 s is not resent', () {
      final now = DateTime.utc(2026, 11, 20, 8);
      expect(GpsIngestionSession.isFresh(fixAt(now.subtract(const Duration(seconds: 10))), now), isTrue);
      expect(GpsIngestionSession.isFresh(fixAt(now.subtract(const Duration(seconds: 31))), now), isFalse);
    });
  });

  group('password rule', () {
    test('at least 8 characters with a letter and a digit, at most 72 bytes', () {
      expect(passwordProblem('Short1'), isNotNull);
      expect(passwordProblem('lettersonly'), isNotNull);
      expect(passwordProblem('12345678'), isNotNull);
      expect(passwordProblem('a1${'x' * 71}'), isNotNull);
      expect(passwordProblem('Commute2026'), isNull);
    });
  });

  group('sign-in session', () {
    setUp(() => FlutterSecureStorage.setMockInitialValues({}));

    test('Remember me keeps the session for the next launch; without it the next launch signs in again', () async {
      const storage = FlutterSecureStorage();
      final adapter = FakeAdapter((o) async => jsonBody(_tokens()));
      final api = ApiService(dio: fakeDio(adapter), secureStorage: storage);

      await api.login('a@b.com', 'Commute2026', rememberMe: true);
      expect(await storage.read(key: rememberMeKey), '1');
      expect((await ApiService(dio: fakeDio(adapter), secureStorage: storage).restoreSession()).accessToken, 'a1');

      await api.login('a@b.com', 'Commute2026');
      expect(await storage.read(key: rememberMeKey), '0');
      await expectLater(ApiService(dio: fakeDio(adapter), secureStorage: storage).restoreSession(), throwsException);
      expect(await storage.read(key: 'refresh_token'), isNull, reason: 'tokens wiped at launch');
    });

    test('logout sends the refresh token so the server can revoke it', () async {
      FlutterSecureStorage.setMockInitialValues({'refresh_token': 'r9', 'access_token': 'a9'});
      final adapter = FakeAdapter((o) async => ResponseBody.fromString('', 204));
      await ApiService(dio: fakeDio(adapter)).logout();
      expect(adapter.requests.single.path, '/auth/logout');
      expect(adapter.requests.single.data, {'refresh_token': 'r9'});
    });

    test('a Google account with two-factor gets the code challenge', () async {
      final adapter = FakeAdapter((o) async => jsonBody(
          {'two_factor_required': true, 'email': 'j***@gmail.com', 'login_email': 'juan@gmail.com', 'message': 'x'},
          status: 202));
      final api = ApiService(dio: fakeDio(adapter));
      await expectLater(
        api.loginWithGoogle('google-token'),
        throwsA(isA<TwoFactorRequired>()
            .having((c) => c.email, 'email', 'juan@gmail.com')
            .having((c) => c.maskedEmail, 'masked', 'j***@gmail.com')),
      );
    });
  });

  group('turning off two-factor', () {
    testWidgets('a password account confirms with the current password', (tester) async {
      final adapter = FakeAdapter((o) async => jsonBody({}));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: TwoFactorOffDialog(service: ProfileService(fakeDio(adapter)), hasPassword: true))));
      await tester.enterText(find.byKey(const Key('two-factor-off-input')), 'Commute2026');
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      final sent = adapter.requests.single;
      expect(sent.path, '/users/me/settings');
      expect(sent.data, {'two_factor_enabled': false, 'current_password': 'Commute2026'});
    });

    testWidgets('a Google-only account gets an emailed code first', (tester) async {
      final adapter = FakeAdapter((o) async =>
          o.path.endsWith('disable-code') ? jsonBody({'email': 'j***@gmail.com'}) : jsonBody({}));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: TwoFactorOffDialog(service: ProfileService(fakeDio(adapter)), hasPassword: false))));
      await tester.tap(find.text('Email me a code'));
      await tester.pumpAndSettle();
      expect(adapter.requests.first.path, '/users/me/two-factor/disable-code');
      await tester.enterText(find.byKey(const Key('two-factor-off-input')), '123456');
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(adapter.requests.last.data, {'two_factor_enabled': false, 'otp': '123456'});
    });
  });

  group('commuter feedback', () {
    testWidgets('sends the category, message and optional route', (tester) async {
      final adapter = FakeAdapter((o) async => jsonBody({'id': 'f1'}, status: 201));
      final route = TransportRoute(id: 'r1', name: 'SM – UC', code: '10M', geometry: const [], stops: const [], isActive: true);
      await tester.pumpWidget(MaterialApp(
          home: SendFeedbackScreen(service: ProfileService(fakeDio(adapter)), routes: [route])));
      await tester.enterText(find.byKey(const Key('feedbackMessage')), 'Driver skipped my stop');
      await tester.tap(find.byKey(const Key('feedbackSend')));
      await tester.pumpAndSettle();
      expect(adapter.requests.single.path, '/feedback');
      expect(adapter.requests.single.data, {'category': 'other', 'message': 'Driver skipped my stop'});
    });

    testWidgets('a refused send shows the server reason', (tester) async {
      final adapter = FakeAdapter((o) async =>
          jsonBody({'detail': 'You can send up to 5 feedback messages an hour. Try again later.'}, status: 429));
      await tester.pumpWidget(MaterialApp(home: SendFeedbackScreen(service: ProfileService(fakeDio(adapter)), routes: const [])));
      await tester.enterText(find.byKey(const Key('feedbackMessage')), 'Hello');
      await tester.tap(find.byKey(const Key('feedbackSend')));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 feedback messages an hour'), findsOneWidget);
    });
  });

  group('place search', () {
    test('server (Photon) results are read from /places/search', () async {
      final adapter = FakeAdapter((o) async => jsonBody([
            {'name': 'Ayala Center', 'kind': 'Mall', 'area': 'Cebu City', 'location': {'type': 'Point', 'coordinates': [123.905, 10.318]}},
          ]));
      final places = await ServerPlaceSearch(fakeDio(adapter)).search('ayala', near: const LatLng(10.3, 123.9));
      expect(adapter.requests.single.path, '/places/search');
      expect(adapter.requests.single.queryParameters, {'q': 'ayala', 'near': '10.3,123.9'});
      expect(places.single.name, 'Ayala Center, Cebu City');
      expect(places.single.location, const LatLng(10.318, 123.905));
    });

    test('online results that repeat a bundled place by name or spot are dropped', () {
      const here = LatLng(10.318, 123.905);
      final local = [(place: const Place(name: 'Ayala Center', location: here, kind: 'Mall'), metres: 0.0)];
      final online = [
        (place: const Place(name: 'ayala center', location: LatLng(10.33, 123.95), kind: 'Mall'), metres: 0.0),
        (place: const Place(name: 'Ayala Mall Entrance', location: LatLng(10.3181, 123.9051), kind: 'Mall'), metres: 0.0),
        (place: const Place(name: 'IT Park', location: LatLng(10.33, 123.906), kind: 'Business'), metres: 0.0),
      ];
      expect(newOnlineMatches(local, online).map((m) => m.place.name), ['IT Park']);
    });
  });

  group('discounted fares', () {
    testWidgets('the fare sheet shows the student, senior or PWD fare', (tester) async {
      final json = sampleResponse();
      final option = (json['options'] as List).first as Map<String, dynamic>;
      option['total_fare_discounted'] = 22;
      ((option['legs'] as List).first as Map<String, dynamic>)['fare_discounted'] = 10;
      final parsed = TripPlanResponse.fromJson(json).options.single;
      expect(parsed.totalFareDiscounted, 22);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FareBreakdownSheet(option: parsed))));
      expect(find.text('Student, senior or PWD: ₱22.00'), findsOneWidget);
      expect(find.text('₱10.00 discounted'), findsOneWidget);
    });
  });

  group('driver traffic report', () {
    testWidgets('Congested and Clear call back; disabled off shift', (tester) async {
      final calls = <bool>[];
      await tester.pumpWidget(_wrap(TrafficReportCard(reported: null, onReport: calls.add)));
      await tester.tap(find.byKey(const Key('trafficCongested')));
      await tester.tap(find.byKey(const Key('trafficClear')));
      expect(calls, [true, false]);
      await tester.pumpWidget(_wrap(const TrafficReportCard(reported: null, onReport: null)));
      expect(find.text('You can report traffic once your shift starts.'), findsOneWidget);
    });
  });
}
