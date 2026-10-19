// lib/services/walking_route_service.dart
//
// Walking path between two points along footpaths and streets, from the
// free OpenStreetMap routing service (FOSSGIS, OSRM "foot" profile). If it
// can't be reached, a straight line with a walking-pace estimate is used,
// so the commuter always gets an answer.

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'boarding_planner.dart';

class WalkingRoute {
  const WalkingRoute({required this.points, required this.metres, required this.seconds, required this.byRoad});

  final List<LatLng> points;
  final double metres;
  final double seconds;

  /// False when this is the straight-line fallback.
  final bool byRoad;

  int get steps => stepsFor(metres);
  int get minutes => (seconds / 60).ceil().clamp(1, 1 << 20);
}

class WalkingRouteService {
  WalkingRouteService({Dio? http})
      : _http = http ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 8),
              headers: {'User-Agent': 'SmartCommute/1.0 (commuter app)'},
            ));

  static const String _base = 'https://routing.openstreetmap.de/routed-foot/route/v1/driving';
  final Dio _http;
  final Map<String, WalkingRoute> _cache = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)};'
      '${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  static WalkingRoute straight(LatLng from, LatLng to) {
    final m = const Distance().as(LengthUnit.Meter, from, to);
    return WalkingRoute(points: [from, to], metres: m, seconds: m / walkMetresPerSecond, byRoad: false);
  }

  Future<WalkingRoute> route(LatLng from, LatLng to) async {
    final key = _key(from, to);   // ~10 m grid: GPS jitter reuses the answer
    final cached = _cache[key];
    if (cached != null) return cached;
    try {
      final res = await _http.get<Map<String, dynamic>>(
        '$_base/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
        queryParameters: {'overview': 'full', 'geometries': 'geojson'},
      );
      final routes = res.data?['routes'] as List?;
      if (routes == null || routes.isEmpty) return straight(from, to);
      final r = routes.first as Map<String, dynamic>;
      final coords = (r['geometry']['coordinates'] as List)
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      final walk = WalkingRoute(
        // Start and end exactly at the commuter and the boarding spot.
        points: [from, ...coords, to],
        metres: (r['distance'] as num).toDouble(),
        seconds: (r['duration'] as num).toDouble(),
        byRoad: true,
      );
      if (_cache.length > 50) _cache.clear();
      return _cache[key] = walk;
    } catch (_) {
      return straight(from, to);
    }
  }
}
