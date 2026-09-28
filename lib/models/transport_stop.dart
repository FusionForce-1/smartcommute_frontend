import 'package:latlong2/latlong.dart';

// lib/models/transport_stop.dart
// File ni siya nag represent sa Details unsa i request sa API para sa Transport Stop
// Mao ning mga data i ask sa API
class TransportStop {
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
