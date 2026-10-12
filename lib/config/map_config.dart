// lib/config/map_config.dart
//
// Shared map settings para parehas ang Live Map ug Pick-on-map screen.

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapConfig {
  MapConfig._();

  // Service area sa app (Metro Cebu: Talisay, Cebu City, Mandaue, Lapu-Lapu, Consolacion).
  // Usba ni kung mo-expand ang coverage.
  static final LatLngBounds serviceArea = LatLngBounds(
    const LatLng(10.20, 123.80), // southwest
    const LatLng(10.45, 124.05), // northeast
  );
  // How far the maps can pan: the whole Philippines (covers all of Cebu
  // island too). Separate from [serviceArea], which is where routes exist.
  static final LatLngBounds mapBounds = LatLngBounds(
    const LatLng(4.40, 116.90), // southwest (Tawi-Tawi / Palawan)
    const LatLng(21.30, 127.00), // northeast (Batanes / east coast)
  );
  static const LatLng defaultCenter = LatLng(10.3157, 123.8854);
  // 5 fits the whole country on a phone screen.
  static const double minZoom = 5;
  static const double maxZoom = 18;
  static const String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String userAgentPackageName = 'com.smartcommute.app';
}
