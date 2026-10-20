// Stops on the Home live map: small dots when zoomed out (so stops along
// the same streets don't pile up), photo pins once zoomed in.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/config/map_config.dart';
import 'package:smartcommute_app/models/transport_stop.dart';
import 'package:smartcommute_app/widgets/commuter/live_map.dart';
import 'package:smartcommute_app/widgets/stop_image.dart';

void main() {
  setUp(() => dotenv.loadFromString(envString: 'API_BASE_URL=http://test'));

  testWidgets('stops are dots zoomed out and photo pins zoomed in', (tester) async {
    final center = MapConfig.defaultCenter;
    final stops = [
      for (var i = 0; i < 3; i++)
        TransportStop(
          id: 's$i',
          name: 'Stop $i',
          location: LatLng(center.latitude + i * 0.001, center.longitude),
          routeIds: const ['r1'],
          sequence: i,
        ),
    ];
    final controller = MapController();
    final frame = ValueNotifier(0);
    addTearDown(frame.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: LiveMap(
          controller: controller,
          stops: stops,
          tracks: const {},
          clock: Stopwatch(),
          frame: frame,
          onMapReady: () {},
        ),
      ),
    ));
    await tester.pump();

    // Starts at zoom 13.
    expect(find.byKey(const Key('stopDot')), findsNWidgets(3));
    expect(find.byType(StopImageMarker), findsNothing);

    controller.move(center, 16);
    await tester.pump();
    expect(find.byKey(const Key('stopDot')), findsNothing);
    expect(find.byType(StopImageMarker), findsNWidgets(3));
  });
}
