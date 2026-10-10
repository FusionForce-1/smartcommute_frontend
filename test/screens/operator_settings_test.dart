import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/screens/operator/operator_settings.dart';
import 'package:smartcommute_app/services/alerts_service.dart';
import 'package:smartcommute_app/services/api_service.dart';
import 'package:smartcommute_app/services/settings_service.dart';

import '../support/fake_dio.dart';

Map<String, dynamic> _settings({bool email = true, bool twoFactor = false}) => {
      'email_notifications': email,
      'two_factor_enabled': twoFactor,
      'language': 'en-PH',
    };

Future<FakeAdapter> _pump(WidgetTester tester, FakeHandler handler) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final adapter = FakeAdapter((options) async {
    if (options.path == '/operators/me') {
      return jsonBody({'company_name': 'Cebu City Transport Co.', 'is_verified': true});
    }
    return handler(options);
  });
  final dio = fakeDio(adapter);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: OperatorSettings(
        service: SettingsService(dio),
        profileService: AlertsService(dio),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

bool _switchValue(WidgetTester tester, int index) =>
    tester.widget<Switch>(find.byType(Switch).at(index)).value;

void main() {
  testWidgets('shows the saved settings from GET /users/me/settings', (tester) async {
    await _pump(tester, (options) async => jsonBody(_settings(twoFactor: true)));

    expect(find.text('Cebu City Transport Co.'), findsOneWidget);
    expect(find.text('Email Notifications'), findsOneWidget);
    expect(find.text('Two-Factor Authentication'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('English (Philippines)'), findsWidgets);
    expect(_switchValue(tester, 0), isTrue);
    expect(_switchValue(tester, 1), isTrue);
  });

  testWidgets('turning off email notifications saves it', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.method == 'PATCH') return jsonBody(_settings(email: false));
      return jsonBody(_settings());
    });

    await tester.tap(find.byType(Switch).at(0));
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.path, '/users/me/settings');
    expect(patch.data, {'email_notifications': false});
    expect(_switchValue(tester, 0), isFalse);
  });

  testWidgets('turning on two-factor needs the emailed code', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.path == '/users/me/two-factor/start') {
        return jsonBody({'email': 'op******@cebulines.ph', 'message': 'Code sent.'});
      }
      if (options.path == '/users/me/two-factor/confirm') {
        return (options.data as Map)['otp'] == '123456'
            ? jsonBody(_settings(twoFactor: true))
            : jsonBody({'detail': 'Incorrect or expired code. Request a new one and try again.'},
                status: 400);
      }
      return jsonBody(_settings());
    });

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining('op******@cebulines.ph'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn On'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect or expired code. Request a new one and try again.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn On'));
    await tester.pumpAndSettle();

    expect(find.text('Turn on two-factor authentication'), findsNothing);
    expect(_switchValue(tester, 1), isTrue);
    expect(adapter.requests.where((r) => r.path == '/users/me/two-factor/confirm'), hasLength(2));
  });

  testWidgets('cancelling the code dialog leaves two-factor off', (tester) async {
    await _pump(tester, (options) async {
      if (options.path == '/users/me/two-factor/start') {
        return jsonBody({'email': 'op******@cebulines.ph'});
      }
      return jsonBody(_settings());
    });

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(_switchValue(tester, 1), isFalse);
  });

  testWidgets('turning off two-factor asks first', (tester) async {
    final adapter = await _pump(tester, (options) async {
      if (options.method == 'PATCH') return jsonBody(_settings());
      return jsonBody(_settings(twoFactor: true));
    });

    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Turn Off'));
    await tester.pumpAndSettle();

    final patch = adapter.requests.singleWhere((r) => r.method == 'PATCH');
    expect(patch.data, {'two_factor_enabled': false});
    expect(_switchValue(tester, 1), isFalse);
  });

  group('ApiService two-factor login', () {
    test('login throws TwoFactorRequired when the server asks for a code', () async {
      final adapter = FakeAdapter((options) async => jsonBody({
            'two_factor_required': true,
            'email': 'op******@cebulines.ph',
            'message': 'Enter the 6-digit code we sent to your email.',
          }, status: 202));
      final api = ApiService(dio: fakeDio(adapter), secureStorage: _MemoryStorage());

      expect(
        () => api.login('operator@cebulines.ph', 'secret123'),
        throwsA(isA<TwoFactorRequired>()
            .having((e) => e.email, 'email', 'operator@cebulines.ph')
            .having((e) => e.maskedEmail, 'maskedEmail', 'op******@cebulines.ph')),
      );
    });

    test('verifyLoginCode stores the tokens', () async {
      final storage = _MemoryStorage();
      final adapter = FakeAdapter((options) async => jsonBody({
            'access_token': 'a',
            'refresh_token': 'r',
            'token_type': 'bearer',
            'role': 'operator',
            'expires_in': 900,
          }));
      final api = ApiService(dio: fakeDio(adapter), secureStorage: storage);

      final tokens = await api.verifyLoginCode('operator@cebulines.ph', '123456');
      expect(tokens.role, 'operator');
      expect(adapter.requests.single.path, '/auth/login/verify');
      expect(adapter.requests.single.data, {'email': 'operator@cebulines.ph', 'otp': '123456'});
      expect(storage.values['access_token'], 'a');
    });
  });
}

/// In-memory stand-in for the platform keychain.
class _MemoryStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) values[key] = value;
  }
}
