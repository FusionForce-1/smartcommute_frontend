// With a route selected, the Home map shows only that trip: no other stops,
// and only the jeeps on its routes.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/config/map_config.dart';
import 'package:smartcommute_app/models/models.dart' show GeoJSONPoint, StopModel;
import 'package:smartcommute_app/models/transport_stop.dart';
import 'package:smartcommute_app/models/trip_plan.dart';
import 'package:smartcommute_app/models/vehicle_live_update.dart';
import 'package:smartcommute_app/models/vehicle_track.dart';
import 'package:smartcommute_app/widgets/commuter/live_map.dart';
import 'package:smartcommute_app/widgets/commuter/trip_route_layers.dart';
import 'package:smartcommute_app/widgets/commuter/vehicle_marker.dart';

void main() {
  setUp(() => dotenv.loadFromString(envString: 'API_BASE_URL=http://test'));

  final center = MapConfig.defaultCenter;
  final stops = [
    for (var i = 0; i < 3; i++)
      TransportStop(
        id: 's$i', name: 'Stop $i', sequence: i, routeIds: const ['r1'],
        location: LatLng(center.latitude + i * 0.001, center.longitude),
      ),
  ];
  VehicleTrack jeep(String id, double dLat) => VehicleTrack(
        VehicleLiveUpdate(vehicleId: id, status: 'en_route', location: LatLng(center.latitude + dLat, center.longitude)),
        Duration.zero,
      );
  final tracks = {'mine': jeep('mine', 0.0005), 'other': jeep('other', 0.0015)};

  StopModel stop(String name, double dLat) => StopModel(
      id: name, name: name, sequence: 1, location: GeoJSONPoint(lat: center.latitude + dLat, lng: center.longitude));
  final trip = TripRouteLayers.of(
    RouteOption(rank: 1, totalEtaMin: 10, totalFare: 13, transfers: 0, legs: [
      RouteLeg(
        routeId: 'r1', routeName: 'R1', boardStop: stop('Board', 0), alightStop: stop('Alight', 0.002),
        etaMin: 10, fare: 13,
        path: [center, LatLng(center.latitude + 0.002, center.longitude)],
      ),
    ]),
    const {},
  );

  Future<void> pump(WidgetTester tester,
      {TripRouteLayers? trip, Set<String>? only, LatLng? here, String? riding}) async {
    final frame = ValueNotifier(0);
    addTearDown(frame.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LiveMap(
          controller: MapController(),
          stops: stops,
          tracks: tracks,
          clock: Stopwatch(),
          frame: frame,
          onMapReady: () {},
          trip: trip,
          onlyVehicles: only,
          currentLocation: here,
          ridingVehicleId: riding,
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('without a trip every jeep shows, but no stop dots', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('stopDot')), findsNothing);
    expect(find.byType(VehicleMarker), findsNWidgets(2));
  });

  testWidgets('a selected trip hides the other stops and jeeps', (tester) async {
    await pump(tester, trip: trip, only: {'mine'});
    expect(find.byKey(const Key('stopDot')), findsNothing);
    expect(find.byType(VehicleMarker), findsOneWidget);
    expect(find.byType(PolylineLayer), findsWidgets);
  });

  testWidgets('riding a jeep merges you into it: one icon', (tester) async {
    final here = LatLng(center.latitude + 0.0005, center.longitude);
    await pump(tester, here: here);
    expect(find.byTooltip('You are here'), findsOneWidget);
    expect(find.byKey(const Key('ridingMarker')), findsNothing);

    await pump(tester, here: here, riding: 'mine');
    expect(find.byTooltip('You are here'), findsNothing);
    expect(find.byKey(const Key('ridingMarker')), findsOneWidget);
    expect(find.byType(VehicleMarker), findsNWidgets(2), reason: 'the other jeep still shows');
  });
}
