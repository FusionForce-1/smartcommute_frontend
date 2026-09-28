import 'package:latlong2/latlong.dart';

class TransportRoute {
  const TransportRoute({
    required this.id,
    required this.name,
    required this.code,
    required this.geometry,
    required this.stops,
    required this.isActive,
  });

  final String id;
  final String name;
  final String code;
  final List<LatLng> geometry;
  final List<RouteStop> stops;
  final bool isActive;

  factory TransportRoute.fromJson(Map<String, dynamic> json) {
    final geometryData =
        json['geometry'] as Map<String, dynamic>;

    final coordinates =
        geometryData['coordinates'] as List<dynamic>;

    final stopsData =
        json['stops'] as List<dynamic>;

    return TransportRoute(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      geometry: coordinates.map((coordinate) {
        final point = coordinate as List<dynamic>;

        return LatLng(
          (point[1] as num).toDouble(),
          (point[0] as num).toDouble(),
        );
      }).toList(),
      stops: stopsData.map((stop) {
        return RouteStop.fromJson(
          stop as Map<String, dynamic>,
        );
      }).toList(),
      isActive: json['is_active'] as bool,
    );
  }
}

class RouteStop {
  const RouteStop({
    required this.id,
    required this.name,
    required this.sequence,
    required this.location,
  });

  final String id;
  final String name;
  final int sequence;
  final LatLng location;

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    final locationData =
        json['location'] as Map<String, dynamic>;

    final coordinates =
        locationData['coordinates'] as List<dynamic>;

    return RouteStop(
      id: json['id'] as String,
      name: json['name'] as String,
      sequence: json['sequence'] as int,
      location: LatLng(
        (coordinates[1] as num).toDouble(),
        (coordinates[0] as num).toDouble(),
      ),
    );
  }
}