import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/models/models.dart' show GeoJSONPoint, StopModel;
import 'package:smartcommute_app/models/transport_model.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/models/vehicles.dart';
import 'package:smartcommute_app/screens/commuter/route_map_screen.dart';
import 'package:smartcommute_app/services/websocket_service.dart';

/// Stands in for /ws/live: the test pushes broadcasts with [send].
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

void main() {
  // Route 17C runs west -> east along one street; the commuter boards at
  // Stop B in the middle.
  const route = TransportRoute(
    id: 'r17c', name: 'Central Bloc – Carbon', code: '17C',
    geometry: [LatLng(10.3000, 123.8800), LatLng(10.3000, 123.9000)], stops: [], isActive: true,
  );
  StopModel stop(String id, String name, double lng) => StopModel(
      id: id, name: name, sequence: 1, location: GeoJSONPoint(lat: 10.3000, lng: lng));
  final option = RouteOption(rank: 1, totalEtaMin: 10, totalFare: 13, transfers: 0, legs: [
    RouteLeg(
      routeId: 'r17c', routeName: 'Central Bloc – Carbon', routeCode: '17C',
      boardStop: stop('b', 'Stop B', 123.8900), alightStop: stop('c', 'Stop C', 123.8990),
      etaMin: 10, fare: 13,
    ),
  ]);
  const fleet = [
    Vehicle(id: 'jeep1', plateNumber: '0000', routeId: 'r17c', status: 'active'),
    Vehicle(id: 'other', plateNumber: 'OTHER-1', routeId: 'elsewhere', status: 'active'),
  ];
  Map<String, dynamic> fix(String id, double lng) => {
        'vehicle_id': id, 'lat': 10.3000, 'lng': lng, 'speed': 0.0, 'heading': null,
        'ts': '2026-10-20 10:31:30.304234', 'status': 'en_route', 'crowd': 'low',
        'duty_status': 'on_route', 'eta_next_stop': -1, 'next_stop': null, 'traffic': null,
      };

  Future<FakeSocket> open(WidgetTester tester) async {
    final socket = FakeSocket();
    await tester.pumpWidget(MaterialApp(
      home: RouteMapScreen(
        option: option,
        routesById: {route.id: route},
        loadVehicles: () async => fleet,
        socket: socket,
      ),
    ));
    await tester.pump();
    return socket;
  }

  testWidgets('a jeep live on the chosen route can be picked', (tester) async {
    final socket = await open(tester);
    expect(find.textContaining('No PUV on this route is sending GPS'), findsOneWidget);

    socket.send(fix('other', 123.8850)); // another route: ignored
    socket.send(fix('jeep1', 123.8850)); // ~550 m west of Stop B, heading to it
    await tester.pump(const Duration(seconds: 2));

    expect(find.text('OTHER-1'), findsNothing);
    expect(find.text('0000'), findsOneWidget);
    expect(find.textContaining('before Stop B'), findsOneWidget);

    await tester.tap(find.text('0000'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('tap one to follow it'), findsOneWidget);
  });

  testWidgets('a jeep past the boarding stop says so', (tester) async {
    final socket = await open(tester);
    socket.send(fix('jeep1', 123.8950));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Already passed Stop B'), findsOneWidget);
  });
}
