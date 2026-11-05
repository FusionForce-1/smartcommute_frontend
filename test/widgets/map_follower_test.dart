// The camera following what moves: it glides there, keeps the chosen zoom,
// ignores GPS jitter, and stops when the map is dragged.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/widgets/map_follower.dart';

const start = LatLng(10.30, 123.90);

Future<(MapController, MapFollower)> pumpMap(WidgetTester tester) async {
  final map = MapController();
  final follow = MapFollower(map, tester);
  addTearDown(follow.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: FlutterMap(
        mapController: map,
        options: MapOptions(
          initialCenter: start,
          initialZoom: 13,
          onMapReady: follow.mapReady,
          onMapEvent: follow.onMapEvent,
        ),
        children: const [],
      ),
    ),
  ));
  await tester.pump();
  return (map, follow);
}

void expectAt(MapController map, LatLng point) {
  expect(map.camera.center.latitude, closeTo(point.latitude, 1e-6));
  expect(map.camera.center.longitude, closeTo(point.longitude, 1e-6));
}

void main() {
  testWidgets('glides to what it follows, at street level the first time', (tester) async {
    final (map, follow) = await pumpMap(tester);

    follow.center(const LatLng(10.31, 123.91));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(map.camera.center.latitude, inExclusiveRange(10.30, 10.31), reason: 'on its way, not jumped');

    await tester.pumpAndSettle();
    expectAt(map, const LatLng(10.31, 123.91));
    expect(map.camera.zoom, MapFollower.streetZoom);
  });

  testWidgets('keeps the zoom the person picked', (tester) async {
    final (map, follow) = await pumpMap(tester);
    follow.center(start);
    await tester.pumpAndSettle();

    map.move(map.camera.center, 14);   // the zoom buttons do this
    expect(follow.following.value, isTrue, reason: 'zooming is not looking away');

    follow.center(const LatLng(10.31, 123.90));
    await tester.pumpAndSettle();
    expectAt(map, const LatLng(10.31, 123.90));
    expect(map.camera.zoom, 14);
  });

  testWidgets('GPS jitter does not move the map', (tester) async {
    final (map, follow) = await pumpMap(tester);
    follow.center(start);
    await tester.pumpAndSettle();
    final before = map.camera.center;

    follow.center(const LatLng(10.30001, 123.90001));   // ~1.5 m
    await tester.pumpAndSettle();

    expect(map.camera.center, before);
  });

  testWidgets('dragging stops it, and resume starts it again at street level', (tester) async {
    final (map, follow) = await pumpMap(tester);
    follow.center(start);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(FlutterMap), const Offset(-120, 40));
    await tester.pumpAndSettle();
    expect(follow.following.value, isFalse);

    final dragged = map.camera.center;
    follow.center(const LatLng(10.31, 123.91));
    await tester.pumpAndSettle();
    expect(map.camera.center, dragged);

    map.move(dragged, 12);
    follow.resume();
    follow.center(const LatLng(10.31, 123.91));
    await tester.pumpAndSettle();
    expectAt(map, const LatLng(10.31, 123.91));
    expect(map.camera.zoom, MapFollower.streetZoom);
  });

  testWidgets('dragging stops a glide half way', (tester) async {
    final (map, follow) = await pumpMap(tester);
    follow.center(const LatLng(10.40, 123.90));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.drag(find.byType(FlutterMap), const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(map.camera.center.latitude, inExclusiveRange(10.30, 10.40));
  });

  group('frame', () {
    bool inView(MapController map, LatLng p) => map.camera.visibleBounds.contains(p);

    testWidgets('keeps everything on the map', (tester) async {
      final (map, follow) = await pumpMap(tester);
      const you = LatLng(10.30, 123.90), jeep = LatLng(10.33, 123.93);

      follow.frame(const [you, jeep]);
      await tester.pumpAndSettle();

      expect(inView(map, you) && inView(map, jeep), isTrue);
    });

    testWidgets('leaves the map alone while they stay well in view', (tester) async {
      final (map, follow) = await pumpMap(tester);
      const you = LatLng(10.30, 123.90), jeep = LatLng(10.33, 123.93);
      follow.frame(const [you, jeep]);
      await tester.pumpAndSettle();
      final before = map.camera;

      follow.frame(const [you, LatLng(10.329, 123.929)]);
      await tester.pumpAndSettle();

      expect(map.camera.center, before.center);
      expect(map.camera.zoom, before.zoom);
    });

    testWidgets('reframes when one is about to leave', (tester) async {
      final (map, follow) = await pumpMap(tester);
      const you = LatLng(10.30, 123.90);
      follow.frame(const [you, LatLng(10.33, 123.93)]);
      await tester.pumpAndSettle();

      const further = LatLng(10.40, 124.00);
      follow.frame(const [you, further]);
      await tester.pumpAndSettle();

      expect(inView(map, you) && inView(map, further), isTrue);
    });

    testWidgets('zooms back in when they have drawn together', (tester) async {
      final (map, follow) = await pumpMap(tester);
      const you = LatLng(10.30, 123.90);
      follow.frame(const [you, LatLng(10.40, 124.00)]);
      await tester.pumpAndSettle();
      final wide = map.camera.zoom;

      follow.frame(const [you, LatLng(10.302, 123.902)]);
      await tester.pumpAndSettle();

      expect(map.camera.zoom, greaterThan(wide + 1));
    });
  });
}
