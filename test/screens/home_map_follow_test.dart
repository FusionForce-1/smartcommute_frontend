// Home tab: the map opens on the commuter and moves with them, keeps them and
// a picked jeep both in view, and the card says how far the jeep is and how
// long the walk takes, to the stop or to the jeep.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/models.dart' show GeoJSONPoint, StopModel;
import 'package:smartcommute_app/models/selected_trip.dart';
import 'package:smartcommute_app/models/transport_model.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/models/vehicles.dart';
import 'package:smartcommute_app/screens/commuter/home.dart';
import 'package:smartcommute_app/services/walking_route_service.dart';
import 'package:smartcommute_app/services/websocket_service.dart';

class FakeSocket extends WebSocketService {
  void Function(dynamic)? _listener;
  @override
  void connect() {}
  @override
  void listenForMessages(void Function(dynamic message) onMessage) => _listener = onMessage;
  @override
  void disconnect() {}
  void send(Map<String, dynamic> msg) => _listener?.call(jsonEncode(msg));
}

/// Answers at once: 80 s of walking per 100 m, by road.
class FakeWalking extends WalkingRouteService {
  @override
  Future<WalkingRoute> route(LatLng from, LatLng to) async {
    final m = const Distance().as(LengthUnit.Meter, from, to);
    return WalkingRoute(points: [from, to], metres: m, seconds: m * 0.8, byRoad: true);
  }
}

Position at(double lat, double lng, {double speed = 1}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.utc(2026, 11, 5, 8),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: speed,
      speedAccuracy: 0,
    );

// Route 17C runs west -> east along lat 10.300, with a stop at its middle.
const route = TransportRoute(
  id: 'r',
  name: 'Central Bloc – Carbon',
  code: '17C',
  geometry: [LatLng(10.300, 123.880), LatLng(10.300, 123.900)],
  stops: [RouteStop(id: 's', name: 'Fuente Stop', sequence: 1, location: LatLng(10.300, 123.890))],
  isActive: true,
);
const vehicle = Vehicle(id: 'jeep', plateNumber: '0000', routeId: 'r', status: 'active');
const you = LatLng(10.302, 123.890);   // ~220 m north of the stop

Map<String, dynamic> frame(double lng, {int second = 0, double? heading}) => {
      'vehicle_id': 'jeep', 'lat': 10.300, 'lng': lng, 'speed': 20.0, 'heading': heading,
      'ts': '2026-11-05 08:00:${second.toString().padLeft(2, '0')}.000000', 'status': 'en_route', 'crowd': 'low',
      'duty_status': 'on_route', 'eta_next_stop': 9, 'next_stop': null, 'traffic': null,
    };

class Harness {
  final positions = StreamController<Position>.broadcast();
  final socket = FakeSocket();
}

Future<Harness> pumpHome(WidgetTester tester, {SelectedTrip? trip, Size size = const Size(414, 1200)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = Harness();
  addTearDown(h.positions.close);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: HomeTab(
        stops: const [],
        routes: const [route],
        vehicles: const [vehicle],
        selectedTrip: trip,
        positions: h.positions.stream,
        socket: h.socket,
        walking: FakeWalking(),
      ),
    ),
  ));
  await tester.pump();
  return h;
}

MapCamera camera(WidgetTester tester) => tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

Future<void> move(WidgetTester tester, Harness h, LatLng to) async {
  h.positions.add(at(to.latitude, to.longitude));
  await tester.pumpAndSettle();
}

void expectCenteredOn(WidgetTester tester, LatLng point) {
  expect(camera(tester).center.latitude, closeTo(point.latitude, 1e-5));
  expect(camera(tester).center.longitude, closeTo(point.longitude, 1e-5));
}

void main() {
  setUp(() => dotenv.loadFromString(
        envString: 'API_BASE_URL=http://127.0.0.1:9\nWS_BASE_URL=ws://127.0.0.1:9',
      ));

  testWidgets('opens on the commuter, at street level, and moves with them', (tester) async {
    final h = await pumpHome(tester);

    await move(tester, h, you);
    expectCenteredOn(tester, you);
    expect(camera(tester).zoom, greaterThanOrEqualTo(16));

    await move(tester, h, const LatLng(10.303, 123.891));
    expectCenteredOn(tester, const LatLng(10.303, 123.891));
  });

  testWidgets('dragging the map stops following; the button starts it again', (tester) async {
    final h = await pumpHome(tester);
    await move(tester, h, you);

    await tester.drag(find.byType(FlutterMap), const Offset(-120, 0));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.location_searching), findsOneWidget, reason: 'the button shows it stopped');
    final dragged = camera(tester).center;

    await move(tester, h, const LatLng(10.303, 123.891));
    expect(camera(tester).center, dragged);

    await tester.tap(find.byTooltip('Center on my location'));
    await tester.pumpAndSettle();
    expectCenteredOn(tester, const LatLng(10.303, 123.891));
    expect(find.byIcon(Icons.my_location), findsWidgets);
  });

  group('a picked jeep', () {
    Future<Harness> pickJeep(WidgetTester tester, {double lng = 123.884, double? heading = 90}) async {
      final h = await pumpHome(tester);
      await move(tester, h, you);
      h.socket.send(frame(lng, heading: heading));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PUV 17C'));
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('stays in view with the commuter as it drives', (tester) async {
      final h = await pickJeep(tester);
      final view = camera(tester).visibleBounds;
      expect(view.contains(you) && view.contains(const LatLng(10.300, 123.884)), isTrue);

      // Far off to the east: a jump that big only counts once three fixes agree.
      for (final second in [1, 2, 3]) {
        h.socket.send(frame(123.960, second: second, heading: 90));
      }
      await tester.pumpAndSettle();

      final wider = camera(tester).visibleBounds;
      expect(wider.contains(you) && wider.contains(const LatLng(10.300, 123.960)), isTrue);
    });

    testWidgets('the card has the km to the jeep and the walks, stop first', (tester) async {
      await pickJeep(tester);

      expect(find.text('The PUV is 0.69 km from you'), findsOneWidget);
      expect(find.text('Walk to Fuente Stop'), findsOneWidget);
      expect(find.text('Walk to the PUV'), findsOneWidget);
      expect(find.textContaining('0.22 km'), findsOneWidget);
      expect(find.text('3 min'), findsOneWidget);    // 221 m at 80 s per 100 m
    });

    testWidgets('says who gets to the stop first', (tester) async {
      await pickJeep(tester);   // 657 m at 20 km/h is 2 min; the commuter's walk is 3
      expect(find.textContaining('0.66 km from that spot'), findsOneWidget);
      expect(find.textContaining('about 1 min before you'), findsOneWidget);
    });

    testWidgets('says when the commuter would get there first', (tester) async {
      await pickJeep(tester, lng: 123.881);   // 985 m away: 3 min, and 3 min is not late
      expect(find.textContaining("You'd get there first"), findsOneWidget);
    });

    testWidgets('tapping a walk draws that one on the map', (tester) async {
      await pickJeep(tester);
      List<LatLng> drawn() => tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .expand((l) => l.polylines)
          .where((p) => p.pattern != const StrokePattern.solid())
          .single
          .points;
      expect(drawn().last.latitude, closeTo(10.300, 1e-6));
      expect(drawn().last.longitude, closeTo(123.890, 1e-6));

      await tester.tap(find.byKey(const Key('walkToJeep')));
      await tester.pumpAndSettle();
      expect(drawn().last.longitude, closeTo(123.884, 1e-6));
    });

    testWidgets('a jeep coming back along the route is on its way, not gone', (tester) async {
      await pickJeep(tester, lng: 123.896, heading: 270);
      expect(find.textContaining('already passed'), findsNothing);
      expect(find.textContaining('from that spot'), findsOneWidget);
    });

    testWidgets('a jeep driving away has passed', (tester) async {
      await pickJeep(tester, lng: 123.896, heading: 90);
      expect(find.textContaining('already passed'), findsOneWidget);
    });
  });

  testWidgets('full screen: the jeep and the commuter are framed clear of the sheet and search bar', (tester) async {
    const north = LatLng(10.320, 123.890);   // ~2 km up the map from the route
    const jeep = LatLng(10.300, 123.884);
    final h = await pumpHome(tester, size: const Size(414, 800));
    await move(tester, h, north);
    h.socket.send(frame(jeep.longitude, heading: 90));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Full screen map'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PUV 17C'));
    await tester.pumpAndSettle();

    final sheetTop = tester.getTopLeft(find.byKey(const Key('nearbySheet'))).dy;
    expect(sheetTop, lessThan(600), reason: 'the sheet is open');
    expect(camera(tester).latLngToScreenOffset(jeep).dy, lessThan(sheetTop));
    expect(camera(tester).latLngToScreenOffset(north).dy, greaterThan(60));
  });

  testWidgets('Nearby Vehicles: km, and when it reaches the commuter', (tester) async {
    final h = await pumpHome(tester);
    await move(tester, h, you);

    h.socket.send(frame(123.884, heading: 90));
    await tester.pumpAndSettle();

    expect(find.text('0.69 km away'), findsOneWidget);
    expect(find.text('to reach you'), findsOneWidget);
    expect(find.text('~2 min'), findsOneWidget, reason: '657 m to the stop at 20 km/h, not its 9 min to its next stop');
  });

  testWidgets('Nearby Vehicles: without our location it falls back to the next stop', (tester) async {
    final h = await pumpHome(tester);

    h.socket.send(frame(123.884, heading: 90));
    await tester.pumpAndSettle();

    expect(find.text('~9 min'), findsOneWidget);
    expect(find.text('to next stop'), findsOneWidget);
  });

  group('a selected route', () {
    StopModel stop(String name, double lng) =>
        StopModel(id: name, name: name, sequence: 1, location: GeoJSONPoint(lat: 10.300, lng: lng));
    final trip = SelectedTrip(
      option: RouteOption(rank: 1, totalEtaMin: 20, totalFare: 13, transfers: 0, legs: [
        RouteLeg(
          routeId: 'r', routeName: '17C', boardStop: stop('Board', 123.880), alightStop: stop('Alight', 123.900),
          etaMin: 20, fare: 13, path: const [LatLng(10.300, 123.880), LatLng(10.300, 123.900)],
        ),
      ]),
      routesById: const {'r': route},
      from: 'Your location',
      to: 'Carbon',
    );

    testWidgets('stays framed until the commuter sets off, then follows them', (tester) async {
      final h = await pumpHome(tester, trip: trip);
      await tester.pumpAndSettle();
      final overview = camera(tester);
      expect(overview.visibleBounds.contains(const LatLng(10.300, 123.880)), isTrue);
      expect(overview.visibleBounds.contains(const LatLng(10.300, 123.900)), isTrue);

      await move(tester, h, you);
      expect(camera(tester).zoom, overview.zoom, reason: 'first fix: still the overview');

      const moved = LatLng(10.3025, 123.890);   // ~55 m on
      await move(tester, h, moved);
      expectCenteredOn(tester, moved);
      expect(camera(tester).zoom, greaterThanOrEqualTo(16));
    });
  });
}
