// Vehicle live update
import 'package:latlong2/latlong.dart';

/// Vehicle live update
class VehicleLiveUpdate {
  /// Create vehicle live update
  const VehicleLiveUpdate({
    required this.vehicleId,
    required this.status,
    this.location,
    this.speed,
    this.heading,
    this.timestamp,
    this.crowd,
    this.etaNextStop,
    this.nextStop,
    this.traffic,
    this.dutyStatus,
    this.source,
    this.shiftEnded = false,
  });

  final String vehicleId;
  final String status;
  final LatLng? location;
  final double? speed;
  final double? heading;
  final DateTime? timestamp;
  final String? crowd;
  final int? etaNextStop;
  final String? nextStop;
  final String? traffic;
  final String? dutyStatus;

  final String? source;

  final bool shiftEnded;

  bool get isSignalLost => status == 'signal_lost';

  bool get isUnavailable => dutyStatus == 'unavailable';

  /// Parse from JSON
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
      nextStop: json['next_stop'] as String?,
      traffic: json['traffic'] as String?,
      dutyStatus: json['duty_status'] as String?,
      source: json['source'] as String?,
      shiftEnded: json['shift_ended'] == true,
    );
  }

  /// Merge vehicle live
  VehicleLiveUpdate? merge(VehicleLiveUpdate update) {
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
        dutyStatus: update.dutyStatus ?? dutyStatus,
        source: source,
      );
    }

    final prev = timestamp;
    final next = update.timestamp;
    if (prev != null && next != null && next.isBefore(prev)) return null;

    return update;
  }
}

/// Parse server time
DateTime? parseServerTime(dynamic value) {
  if (value is! String || value.isEmpty) return null;
  var s = value.replaceFirst(' ', 'T');
  final hasOffset =
      s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
  if (!hasOffset) s = '${s}Z';
  return DateTime.tryParse(s)?.toUtc();
}
