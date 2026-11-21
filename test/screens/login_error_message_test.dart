// Login error banner

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/config/theme_config.dart';
import 'package:smartcommute_app/screens/auth/login_screen.dart';

DioException _serverError(int status, String detail) {
  final options = RequestOptions(path: '/auth/login');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: status, data: {'detail': detail}),
  );
}

Future<void> _loginFailingWith(WidgetTester tester, Object error) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.lightTheme,
    home: LoginScreen(onLogin: (_, __, ___) async => throw error),
  ));
  await tester.enterText(find.byType(EditableText).at(0), 'user@test.com');
  await tester.enterText(find.byType(EditableText).at(1), 'wrongpass');
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pump();
}

void main() {
  for (final detail in const [
    'Account locked. Try again in 10 minutes.',
    'Invalid email or password. 2 attempt(s) remaining.',
    'Account is deactivated. Contact admin.',
  ]) {
    testWidgets('shows server message: $detail', (tester) async {
      await _loginFailingWith(tester, _serverError(401, detail));
      expect(find.text(detail), findsOneWidget);
    });
  }

  testWidgets('unknown error falls back to the default text', (tester) async {
    await _loginFailingWith(tester, Exception('boom'));
    expect(find.text('Invalid email or password.'), findsOneWidget);
  });
}
