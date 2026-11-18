// Transport stop
import 'package:latlong2/latlong.dart';

/// Transport stop
class TransportStop {
  /// Create transport stop
  const TransportStop({
    required this.id,
    required this.name,
    required this.location,
    required this.routeIds,
    required this.sequence,
    this.landmark,
  });

  final String id;
  final String name;
  final LatLng location;
  final List<String> routeIds;
  final int sequence;
  final String? landmark;

  /// Parse from JSON
  factory TransportStop.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    final coordinates =
        location['coordinates'] as List<dynamic>;


    return TransportStop(
      id: json['id'] as String,
      name: json['name'] as String,
      sequence: json['sequence'] as int,
      location: LatLng(
        (coordinates[1] as num).toDouble(),
        (coordinates[0] as num).toDouble(),
      ),
      routeIds: (json['route_ids'] as List<dynamic>)
          .map((routeId) => routeId as String)
          .toList(),
      landmark: json['landmark'] as String?,
    );
  }
}
