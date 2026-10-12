// lib/screens/commuter/route_map_screen.dart
//
// "View Selected Route on Map": draws each leg's route line with its
// board / alight stops, framed to fit, above the fare breakdown.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/models.dart' show StopModel;
import '../../models/transport_model.dart';
import '../../models/trip_plan.dart';
import '../../widgets/commuter/commuter_page_header.dart';
import '../../widgets/fare_breakdown_sheet.dart';

class RouteMapScreen extends StatelessWidget {
  const RouteMapScreen({super.key, required this.option, required this.routesById});

  final RouteOption option;
  final Map<String, TransportRoute> routesById;

  /// One colour per leg, so transfers are easy to see.
  static const _legColors = [AppColors.brandTeal, AppColors.accent, AppColors.primary];

  static LatLng _point(StopModel stop) => LatLng(stop.location.lat, stop.location.lng);

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>[];
    final markers = <Marker>[];

    for (var i = 0; i < option.legs.length; i++) {
      final leg = option.legs[i];
      final route = routesById[leg.routeId];
      if (route != null && route.geometry.length > 1) {
        polylines.add(Polyline(
          points: route.geometry,
          color: _legColors[i % _legColors.length],
          strokeWidth: 5,
        ));
      }
      if (!leg.boardStop.isPlaceholder) {
        markers.add(_stopMarker(_point(leg.boardStop), Icons.trip_origin, AppColors.success));
      }
      if (!leg.alightStop.isPlaceholder) {
        markers.add(_stopMarker(_point(leg.alightStop), Icons.location_on, AppColors.error));
      }
    }

    final points = [
      for (final line in polylines) ...line.points,
      for (final marker in markers) marker.point,
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          const CommuterPageHeader(title: 'Selected Route'),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: points.isEmpty ? MapConfig.defaultCenter : points.first,
                initialZoom: 14,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(40),
                        maxZoom: 16,
                      )
                    : null,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                cameraConstraint: CameraConstraint.contain(bounds: MapConfig.serviceArea),
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: MapConfig.userAgentPackageName,
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
              ],
            ),
          ),
          _FarePanel(option: option),
        ],
      ),
    );
  }

  static Marker _stopMarker(LatLng point, IconData icon, Color color) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: Icon(icon, color: color, size: 32),
    );
  }
}

/// Fare breakdown under the map, scrollable on short screens.
class _FarePanel extends StatelessWidget {
  const _FarePanel({required this.option});

  final RouteOption option;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: SafeArea(top: false, child: FareBreakdownSheet(option: option)),
      ),
    );
  }
}
