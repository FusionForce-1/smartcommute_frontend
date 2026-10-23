import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/config/map_config.dart';
import 'package:smartcommute_app/models/transport_stop.dart';
import 'package:smartcommute_app/screens/commuter/pick_destination_screen.dart';

const inCebu = LatLng(10.31, 123.89);

final fuente = TransportStop(
  id: 'fuente',
  name: 'Fuente Osmeña',
  location: const LatLng(10.3108, 123.8905), // ~100 m from inCebu
  routeIds: const ['r1'],
  sequence: 0,
);

/// Opens the picker from a button and returns what it pops.
Future<List<PickedPlace?>> openPicker(WidgetTester tester, {LatLng? start}) async {
  tester.view.physicalSize = const Size(414, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final results = <PickedPlace?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => results.add(await Navigator.of(context).push<PickedPlace>(
          MaterialPageRoute(
            builder: (_) => PickDestinationScreen(origin: inCebu, stops: [fuente], start: start),
          ),
        )),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return results;
}

void main() {
  test('uses the origin when it is inside the service area', () {
    expect(initialPickCenter(inCebu), inCebu);
  });

  test('falls back to the default center when origin is outside Metro Cebu', () {
    const manila = LatLng(14.5995, 120.9842);

    expect(initialPickCenter(manila), MapConfig.defaultCenter);
  });

  test('falls back to the default center when there is no origin', () {
    expect(initialPickCenter(null), MapConfig.defaultCenter);
  });

  test('labels a pin by its nearest stop, else by coordinates', () {
    expect(pinnedLabel(inCebu, [fuente]), 'Pinned spot · near Fuente Osmeña');
    expect(pinnedLabel(const LatLng(10.40, 123.95), [fuente]), 'Pinned spot (10.4000, 123.9500)');
  });

  testWidgets('says where the pin is and returns it with a readable label', (tester) async {
    final results = await openPicker(tester);

    expect(find.text('Near Fuente Osmeña'), findsOneWidget);
    expect(find.textContaining('m from the pin'), findsOneWidget);

    await tester.tap(find.text('Set destination'));
    await tester.pumpAndSettle();

    expect(results.single!.point, inCebu);
    expect(results.single!.label, 'Pinned spot · near Fuente Osmeña');
  });

  testWidgets('the pin lifts while the map moves and drops after', (tester) async {
    await openPicker(tester);
    double pinLift() =>
        (tester.widget<AnimatedPadding>(find.byKey(const Key('pickPin'))).padding as EdgeInsets).bottom;
    expect(pinLift(), 48);

    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, -150));
    await tester.pump();
    expect(pinLift(), greaterThan(48));

    await gesture.up();
    await tester.pumpAndSettle();
    // Dropped a moment after the map stops moving.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(pinLift(), 48);
    // Dragged away from the stop: the card follows the new spot.
    expect(find.text('Near Fuente Osmeña'), findsNothing);
  });

  testWidgets('reopens at the previously pinned spot', (tester) async {
    const earlier = LatLng(10.3, 123.9);
    final results = await openPicker(tester, start: earlier);

    await tester.tap(find.text('Set destination'));
    await tester.pumpAndSettle();
    expect(results.single!.point, earlier);
  });
}
