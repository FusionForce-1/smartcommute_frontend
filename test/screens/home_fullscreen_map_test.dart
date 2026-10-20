// Home tab: the map's full-screen mode — search on top, buttons on the
// right, "Nearby Vehicles" in a sheet that minimizes to its handle — and
// back again with the collapse button or the Back button.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartcommute_app/screens/commuter/home.dart';
import 'package:smartcommute_app/widgets/commuter/live_map.dart';

Future<void> pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(
      body: HomeTab(stops: [], routes: [], vehicles: []),
    ),
  ));
  await tester.pump();
}

Finder get toggle => find.byKey(const Key('mapExpandToggle'));
Finder get sheet => find.byKey(const Key('nearbySheet'));

void main() {
  setUp(() => dotenv.loadFromString(
        envString: 'API_BASE_URL=http://127.0.0.1:9\nWS_BASE_URL=ws://127.0.0.1:9',
      ));

  testWidgets('expands to full screen with a draggable Nearby Vehicles sheet', (tester) async {
    await pumpHome(tester);
    expect(sheet, findsNothing);
    expect(find.text('Center on my location'), findsOneWidget); // card layout's tile

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(find.text('Nearby Vehicles'), findsOneWidget);
    expect(find.text('Search destination...'), findsOneWidget);
    expect(find.byTooltip('Center on my location'), findsOneWidget); // map button
    expect(find.byType(LiveMap), findsOneWidget);

    // Opened part-way up the screen.
    final opened = tester.getTopLeft(sheet).dy;
    expect(opened, lessThan(896 * 0.8));

    // Tap the handle: minimizes to just the handle.
    await tester.tap(find.byKey(const Key('nearbySheetHandle')));
    await tester.pumpAndSettle();
    final minimized = tester.getTopLeft(sheet).dy;
    expect(minimized, greaterThan(opened));
    expect(896 - minimized, lessThan(40));

    // And back up.
    await tester.tap(find.byKey(const Key('nearbySheetHandle')));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(sheet).dy, closeTo(opened, 1));
  });

  testWidgets('collapse button and Back both leave full screen', (tester) async {
    await pumpHome(tester);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.text('Center on my location'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(find.byType(HomeTab), findsOneWidget); // stayed in the app
  });
}
