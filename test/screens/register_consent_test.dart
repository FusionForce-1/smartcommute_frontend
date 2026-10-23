// The register screen's User Agreement / Privacy Policy consent box:
// registering needs it ticked, and each link opens its document.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/config/theme_config.dart';
import 'package:smartcommute_app/screens/auth/register_screen.dart';

Future<List<String>> pumpRegister(WidgetTester tester, {List<bool>? consent}) async {
  tester.view.physicalSize = const Size(414, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final registered = <String>[];
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: RegisterScreen(
      onRegister: (name, email, password) async => registered.add(email),
      onConsentChanged: consent?.add,
    ),
  ));
  return registered;
}

Future<void> fillForm(WidgetTester tester) async {
  final fields = find.byType(EditableText);
  await tester.enterText(fields.at(0), 'Juan Dela Cruz');
  await tester.enterText(fields.at(1), 'juan@example.com');
  await tester.enterText(fields.at(2), 'secret123');
  await tester.enterText(fields.at(3), 'secret123');
}

Finder get registerButton => find.widgetWithText(ElevatedButton, 'Register');

void main() {
  testWidgets('register is blocked until the consent box is ticked', (tester) async {
    final registered = await pumpRegister(tester);
    await fillForm(tester);

    await tester.tap(registerButton);
    await tester.pump();
    expect(registered, isEmpty);
    expect(find.textContaining('Please agree to the User Agreement'), findsOneWidget);

    await tester.tap(find.byKey(const Key('consentCheckbox')));
    await tester.pump();
    expect(find.textContaining('Please agree to the User Agreement'), findsNothing);

    await tester.tap(registerButton);
    await tester.pumpAndSettle();
    expect(registered, ['juan@example.com']);
  });

  for (final doc in ['User Agreement', 'Privacy Policy']) {
    testWidgets('tapping "$doc" opens it in a popup', (tester) async {
      await pumpRegister(tester);
      await tester.tapOnText(find.textRange.ofSubstring(doc));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text(doc)), findsOneWidget);
      // The link doesn't tick the box.
      expect(tester.widget<Checkbox>(find.byKey(const Key('consentCheckbox'))).value, isFalse);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Close'));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);
    });
  }

  testWidgets('Continue with Google waits for the consent box', (tester) async {
    final consent = <bool>[];
    await pumpRegister(tester, consent: consent);

    await tester.tap(find.byKey(const Key('googleNeedsConsent')));
    await tester.pump();
    expect(find.textContaining('Please agree to the User Agreement'), findsOneWidget);

    await tester.tap(find.byKey(const Key('consentCheckbox')));
    await tester.pump();
    expect(find.byKey(const Key('googleNeedsConsent')), findsNothing);
    expect(consent, [true]);

    // Leaving the screen withdraws it, so a later Google sign-in from the
    // login screen isn't recorded as agreeing.
    await tester.pumpWidget(const SizedBox());
    expect(consent, [true, false]);
  });
}
