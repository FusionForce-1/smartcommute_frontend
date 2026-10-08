import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/widgets/stop_image.dart';

void main() {
  // Walay GOOGLE_MAPS_API_KEY → satellite ra ang source.
  setUp(() => dotenv.loadFromString(envString: 'API_BASE_URL=http://test'));

  testWidgets('without a Street View key, shows Esri satellite tiles centered on the stop', (tester) async {
    const location = LatLng(10.3305449, 123.880357);

    await tester.pumpWidget(const MaterialApp(
      home: Center(
        child: SizedBox(width: 200, height: 125, child: StopImage(location: location)),
      ),
    ));

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, location);
    final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
    // Ang /export endpoint gi-disable na sa Esri (HTTP 500) — tiles ra ang mogana.
    expect(tiles.urlTemplate, contains('World_Imagery/MapServer/tile/{z}/{y}/{x}'));
  });

  testWidgets('the satellite view does not steal taps from the marker', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: GestureDetector(
          onTap: () => taps++,
          child: const SizedBox(
            width: 52,
            height: 52,
            child: StopImage(location: LatLng(10.33, 123.88)),
          ),
        ),
      ),
    ));

    await tester.tap(find.byType(StopImage));
    expect(taps, 1);
  });
}
