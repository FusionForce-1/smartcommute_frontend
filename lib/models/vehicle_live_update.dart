import 'package:latlong2/latlong.dart';

// lib/models/vehicle_live_update.dart
// One frame from WSS /ws/live (broadcast by the backend's gps_ingestion).
//
//   {"vehicle_id", "lat", "lng", "speed", "heading", "ts",
//    "status", "crowd", "eta_next_stop"}
//
// signal_lost frames have NO lat/lng/ts — only vehicle_id + status —
// so [location] and [timestamp] are nullable.
class VehicleLiveUpdate {
  const VehicleLiveUpdate({
    required this.vehicleId,
    required this.status,
    this.location,
    this.speed,
    this.heading,
    this.timestamp,
    this.crowd,
    this.etaNextStop,
  });

  final String vehicleId;
  final String status; // "en_route" | "signal_lost"
  final LatLng? location;
  final double? speed; // km/h
  final double? heading; // degrees from north
  final DateTime? timestamp; // device fix time, UTC
  final String? crowd; // low | medium | high
  final int? etaNextStop; // minutes, -1 when unknown

  bool get isSignalLost => status == 'signal_lost';

  factory VehicleLiveUpdate.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'] as num?;
    final lng = json['lng'] as num?;

    return VehicleLiveUpdate(
      vehicleId: json['vehicle_id'] as String,
      status: json['status'] as String? ?? 'unknown',
      location: lat != null && lng != null
          ? LatLng(lat.toDouble(), lng.toDouble())
          : null,
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: parseServerTime(json['ts']),
      crowd: json['crowd'] as String?,
      etaNextStop: (json['eta_next_stop'] as num?)?.toInt(),
    );
  }

  /// Applies [update] on top of this (the previous state for the same
  /// vehicle). Returns null if [update] is an older fix that arrived out
  /// of order and should be ignored.
  VehicleLiveUpdate? merge(VehicleLiveUpdate update) {
    // Status-only frame (signal_lost): keep the last known position so
    // the marker stays on the map, just flag it.
    if (update.location == null) {
      return VehicleLiveUpdate(
        vehicleId: vehicleId,
        status: update.status,
        location: location,
        speed: speed,
        heading: heading,
        timestamp: timestamp,
        crowd: update.crowd ?? crowd,
        etaNextStop: update.etaNextStop,
      );
    }

    final prev = timestamp;
    final next = update.timestamp;
    if (prev != null && next != null && next.isBefore(prev)) return null;

    return update;
  }
}

/// Parses backend datetimes. Python's str(datetime) uses a space instead
/// of "T", and naive datetimes have no offset even though they are UTC.
DateTime? parseServerTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  var s = value.replaceFirst(' ', 'T');
  final hasOffset =
      s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  if (!hasOffset) s = '${s}Z';
  return DateTime.tryParse(s)?.toUtc();
}
