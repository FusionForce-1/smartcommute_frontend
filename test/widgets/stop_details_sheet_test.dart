import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/transport_stop.dart';
import 'package:smartcommute_app/widgets/stop_image.dart';

const stop = TransportStop(
  id: 's1',
  name: 'Guadalupe Church',
  location: LatLng(10.3305449, 123.880357),
  routeIds: ['r1'],
  sequence: 1,
  landmark: 'Near the Guadalupe parish plaza',
);

Future<void> openSheet(WidgetTester tester, Size window) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showStopDetailsSheet(context, stop),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => dotenv.loadFromString(envString: 'API_BASE_URL=http://test'));

  // Chrome window sa laptop — mao ni nag-overflow ("overlapping pixels").
  testWidgets('fits a wide, short desktop window without overflowing', (tester) async {
    await openSheet(tester, const Size(1366, 657));

    expect(tester.takeException(), isNull);
    expect(find.text('Guadalupe Church'), findsOneWidget);
  });

  testWidgets('fits a phone screen without overflowing', (tester) async {
    await openSheet(tester, const Size(390, 844));

    expect(tester.takeException(), isNull);
    expect(find.text('Guadalupe Church'), findsOneWidget);
  });
}
