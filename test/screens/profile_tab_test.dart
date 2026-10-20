import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/models/commuter_profile.dart';
import 'package:smartcommute_app/providers/profile_provider.dart';
import 'package:smartcommute_app/screens/commuter/profile.dart';
import 'package:smartcommute_app/services/profile_service.dart';
import 'package:smartcommute_app/widgets/commuter/save_route_sheet.dart';

import '../support/commuter_fixtures.dart';
import '../support/fake_dio.dart';

Map<String, Object?> loaded([Map<String, Object?> extra = const {}]) => {
      'GET /users/me': profileJson(),
      'GET /users/me/saved-routes': [savedRouteJson('s1')],
      'GET /users/me/settings': settingsJson(),
      ...extra,
    };

class TabCalls {
  SavedRoute? opened;
  var signedOut = 0;
  var createdAccount = 0;
}

Future<TabCalls> pumpProfileTab(
  WidgetTester tester,
  FakeAdapter backend, {
  bool isGuest = false,
}) async {
  tester.view.physicalSize = const Size(430, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final profile = ProfileProvider(service: ProfileService(fakeDio(backend)), isGuest: isGuest);
  addTearDown(profile.dispose);
  // Real async work (the fake HTTP calls) must run outside the test clock.
  await tester.runAsync(profile.load);

  final calls = TabCalls();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ChangeNotifierProvider.value(
        value: profile,
        child: ProfileTab(
          isGuest: isGuest,
          stops: const [],
          routes: const [],
          onOpenSavedRoute: (route) => calls.opened = route,
          onSignOut: () => calls.signedOut++,
          onCreateAccount: () => calls.createdAccount++,
        ),
      ),
    ),
  ));
  return calls;
}

void main() {
  testWidgets('shows the header, stats, saved routes and settings', (tester) async {
    await pumpProfileTab(tester, fakeBackend(loaded()));

    expect(find.text('JD'), findsOneWidget);
    expect(find.text('Juan Dela Cruz'), findsOneWidget);
    expect(find.text('juan.delacruz@gmail.com'), findsOneWidget);
    expect(find.text('Commuter'), findsOneWidget);
    expect(find.text('47'), findsOneWidget);
    expect(find.text('Reviews'), findsNothing);
    expect(find.text('Home → Office'), findsOneWidget);
    expect(find.text('Talamban → Ayala Center Cebu'), findsOneWidget);
    for (final pref in NotificationPref.values) {
      expect(find.text(pref.title), findsOneWidget);
    }
    expect(find.text('Privacy & Security'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('a notification switch saves the choice', (tester) async {
    final backend = fakeBackend(loaded({'PATCH /users/me/settings': settingsJson()}));
    await pumpProfileTab(tester, backend);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Promotions'));
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Promotions')).value, isTrue);
    expect(backend.requests.last.data, {'promotions': true});
  });

  testWidgets('tapping a saved route opens it on the Route tab', (tester) async {
    final calls = await pumpProfileTab(tester, fakeBackend(loaded()));

    await tester.tap(find.text('Home → Office'));

    expect(calls.opened?.id, 's1');
  });

  testWidgets('long-pressing a saved route offers to remove it', (tester) async {
    await pumpProfileTab(tester, fakeBackend(loaded({'DELETE /users/me/saved-routes/s1': null})));

    await tester.longPress(find.text('Home → Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Home → Office'), findsNothing);
  });

  testWidgets('the pencil renames the commuter', (tester) async {
    final renamed = {...profileJson(), 'name': 'Juan D. Cruz'};
    await pumpProfileTab(tester, fakeBackend(loaded({'PATCH /users/me': renamed})));

    await tester.tap(find.byTooltip('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Juan D. Cruz');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Juan D. Cruz'), findsOneWidget);
  });

  testWidgets('+ Add opens the save-a-route form', (tester) async {
    await pumpProfileTab(tester, fakeBackend(loaded()));

    await tester.tap(find.text('+ Add'));
    await tester.pumpAndSettle();

    expect(find.byType(SaveRouteSheet), findsOneWidget);
    expect(find.text('Save a Route'), findsOneWidget);
  });

  testWidgets('Sign out signs out', (tester) async {
    final calls = await pumpProfileTab(tester, fakeBackend(loaded()));

    await tester.tap(find.text('Sign out'));

    expect(calls.signedOut, 1);
  });

  testWidgets('a failed load offers Try again', (tester) async {
    await pumpProfileTab(tester, fakeBackend(loaded({'GET /users/me': 500})));

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('guests are asked to sign in', (tester) async {
    final calls = await pumpProfileTab(tester, fakeBackend(loaded()), isGuest: true);

    expect(find.text("You're browsing as a guest"), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    expect(calls.signedOut, 1);

    await tester.tap(find.text('Create an account'));
    expect(calls.createdAccount, 1);
  });

  testWidgets('Terms & Privacy Policy lets you read either document', (tester) async {
    await pumpProfileTab(tester, fakeBackend(loaded()), isGuest: true);

    await tester.tap(find.text('Terms & Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('User Agreement'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('Data Privacy Act of 2012'), findsOneWidget);
  });

  testWidgets('Help & Support opens the FAQ', (tester) async {
    await pumpProfileTab(tester, fakeBackend(loaded()), isGuest: true);

    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    expect(find.text('Frequently asked questions'), findsOneWidget);

    await tester.tap(find.text('How do I plan a trip?'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tap Find Routes'), findsOneWidget);
  });

  group('Privacy & Security', () {
    Map<String, Object?> security({bool hasPassword = true, bool termsCurrent = true}) => {
          'two_factor_enabled': false,
          'has_password': hasPassword,
          'auth_provider': hasPassword ? 'local' : 'google',
          'terms_accepted_at': termsCurrent ? '2026-10-20T04:00:00Z' : null,
          'terms_version': termsCurrent ? '2026-10' : null,
          'terms_current': termsCurrent,
        };

    /// Lets real (fake-HTTP) requests finish, then redraws.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pumpAndSettle();
    }

    Future<void> openPage(WidgetTester tester) async {
      await tester.tap(find.text('Privacy & Security'));
      await tester.pumpAndSettle();
      await settle(tester);
    }

    testWidgets('shows sign-in options and when you agreed', (tester) async {
      await pumpProfileTab(tester, fakeBackend(loaded({'GET /users/me/security': security()})));
      await openPage(tester);

      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('Two-factor sign-in'), findsOneWidget);
      expect(find.textContaining('You agreed on October 20, 2026'), findsOneWidget);
      expect(find.text('I agree'), findsNothing);
    });

    testWidgets('changes the password', (tester) async {
      final backend = fakeBackend(loaded({
        'GET /users/me/security': security(),
        'POST /users/me/password': null,
      }));
      await pumpProfileTab(tester, backend);
      await openPage(tester);

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
      await tester.enterText(fields.at(0), 'secret123');
      await tester.enterText(fields.at(1), 'newpass1');
      await tester.enterText(fields.at(2), 'newpass2');
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('New passwords do not match.'), findsOneWidget);

      await tester.enterText(fields.at(2), 'newpass1');
      await tester.tap(find.text('Save'));
      await settle(tester);

      expect(calls(backend), contains('POST /users/me/password'));
      expect(find.text('Your password was changed.'), findsOneWidget);
    });

    testWidgets('Google accounts get no password option and can agree', (tester) async {
      final backend = fakeBackend(loaded({
        'GET /users/me/security': security(hasPassword: false, termsCurrent: false),
        'POST /users/me/accept-terms': security(hasPassword: false),
      }));
      await pumpProfileTab(tester, backend);
      await openPage(tester);

      expect(find.text('Change password'), findsNothing);
      expect(find.text('You sign in with Google'), findsOneWidget);
      expect(find.textContaining('agreed to the latest terms'), findsOneWidget);

      await tester.ensureVisible(find.text('I agree'));
      await tester.tap(find.text('I agree'));
      await settle(tester);

      expect(calls(backend), contains('POST /users/me/accept-terms'));
      expect(find.textContaining('You agreed on'), findsOneWidget);
    });
  });
}
