// Trip route layers
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme_config.dart';
import '../../models/models.dart' show StopModel;
import '../../models/transport_model.dart';
import '../../models/trip_plan.dart';
import '../../services/trip_progress.dart';

/// Trip route layers
class TripRouteLayers {
  /// Create trip route
  TripRouteLayers._(this.lines, this.markers);

  /// Create of trip route
  factory TripRouteLayers.of(RouteOption option, Map<String, TransportRoute> routesById, {TripProgress? progress}) {
    final lines = <Polyline>[];
    final markers = <Marker>[];
    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      final points = leg.path ?? routesById[leg.routeId]?.geometry;
      if (points != null && points.length > 1) {
        final split = progress?.state == null ? (done: const <LatLng>[], ahead: points) : progress!.split(i);
        if (split.done.length > 1) {
          lines.add(Polyline(
            points: split.done,
            color: travelledColor,
            strokeWidth: 5,
            borderStrokeWidth: 1.5,
            borderColor: Colors.white,
          ));
        }
        if (split.ahead.length > 1) {
          lines.add(Polyline(
            points: split.ahead,
            color: legColors[i % legColors.length],
            strokeWidth: 5,
            borderStrokeWidth: 1.5,
            borderColor: Colors.white,
          ));
        }
      }
      if (!leg.boardStop.isPlaceholder) {
        markers.add(_stopMarker(leg.boardStop, Icons.trip_origin, AppColors.success));
      }
      if (!leg.alightStop.isPlaceholder) {
        markers.add(_stopMarker(leg.alightStop, Icons.location_on, AppColors.error));
      }
    }
    return TripRouteLayers._(lines, markers);
  }

  static const legColors = [AppColors.brandTeal, AppColors.accent, AppColors.primary];

  static const travelledColor = Color(0xFFB0B8BF);

  final List<Polyline> lines;
  final List<Marker> markers;

  List<LatLng> get points => [
        for (final line in lines) ...line.points,
        for (final marker in markers) marker.point,
      ];

  CameraFit? get cameraFit {
    final all = points;
    if (all.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: all,
      padding: const EdgeInsets.all(40),
      maxZoom: 16,
    );
  }

  /// Stop marker
  static Marker _stopMarker(StopModel stop, IconData icon, Color color) {
    return Marker(
      point: LatLng(stop.location.lat, stop.location.lng),
      width: 36,
      height: 36,
      child: Icon(icon, color: color, size: 32),
    );
  }
}
