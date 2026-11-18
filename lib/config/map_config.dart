// Map config
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Map config
class MapConfig {
  /// Create map config
  MapConfig._();

  static final LatLngBounds serviceArea = LatLngBounds(
    const LatLng(10.20, 123.80),
    const LatLng(10.45, 124.05),
  );
  static final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(4.40, 116.90),
    const LatLng(21.30, 127.00),
  );
  static const LatLng defaultCenter = LatLng(10.3157, 123.8854);
  static const double minZoom = 5;
  static const double maxZoom = 18;
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackageName = 'com.smartcommute.app';
}
