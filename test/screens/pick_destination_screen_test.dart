import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:smartcommute_app/config/map_config.dart';
import 'package:smartcommute_app/screens/commuter/pick_destination_screen.dart';

void main() {
  test('uses the origin when it is inside the service area', () {
    const inCebu = LatLng(10.31, 123.89);

    expect(initialPickCenter(inCebu), inCebu);
  });

  test('falls back to the default center when origin is outside Metro Cebu', () {
    const manila = LatLng(14.5995, 120.9842);

    expect(initialPickCenter(manila), MapConfig.defaultCenter);
  });

  test('falls back to the default center when there is no origin', () {
    expect(initialPickCenter(null), MapConfig.defaultCenter);
  });
}
