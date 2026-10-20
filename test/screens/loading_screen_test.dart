// The loading screen shows while the app starts, then hands over to the app
// — even if starting up fails.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/screens/loading_screen.dart';

Widget fakeApp(BuildContext _) => const MaterialApp(home: Text('Login'));

void main() {
  testWidgets('shows the logo and spinner until loading finishes', (tester) async {
    final loading = Completer<void>();
    await tester.pumpWidget(AppLoader(load: () => loading.future, builder: fakeApp));

    expect(find.text('Cebu City Transit Information'), findsOneWidget);
    expect(find.byKey(const Key('loadingSpinner')), findsOneWidget);
    expect(find.text('Login'), findsNothing);

    loading.complete();
    await tester.pump();
    expect(find.text('Login'), findsOneWidget);
    expect(find.byKey(const Key('loadingSpinner')), findsNothing);
  });

  testWidgets('a failed start still opens the app', (tester) async {
    await tester.pumpWidget(AppLoader(
      load: () async => throw Exception('no .env'),
      builder: fakeApp,
    ));
    await tester.pump();
    expect(find.text('Login'), findsOneWidget);
  });
}
