// lib/widgets/commuter/live_map.dart
//
// Live Map card: OSM tiles locked to the service area, stop photo pins,
// animated vehicle markers, the commuter's location and zoom buttons.
// Owns no state — the Home tab feeds it data and the map controller.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/transport_stop.dart';
import '../../models/vehicle_track.dart';
import '../stop_image.dart';
import 'vehicle_marker.dart';

class LiveMap extends StatelessWidget {
  const LiveMap({
    super.key,
    required this.controller,
    required this.stops,
    required this.tracks,
    required this.clock,
    required this.frame,
    required this.onMapReady,
    this.currentLocation,
  });

  final MapController controller;
  final List<TransportStop> stops;
  final Map<String, VehicleTrack> tracks;

  /// Shared animation clock; [frame] ticks whenever vehicle markers move.
  final Stopwatch clock;
  final ValueNotifier<int> frame;

  final VoidCallback onMapReady;
  final LatLng? currentLocation;

  void _zoomBy(double delta) {
    final camera = controller.camera;
    final zoom = (camera.zoom + delta).clamp(MapConfig.minZoom, MapConfig.maxZoom);
    controller.move(camera.center, zoom);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        boxShadow: AppShadows.card,
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: MapConfig.defaultCenter,
          initialZoom: 13,
          minZoom: MapConfig.minZoom,
          maxZoom: MapConfig.maxZoom,
          cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
          onMapReady: onMapReady,
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            userAgentPackageName: MapConfig.userAgentPackageName,
          ),
          if (currentLocation case final here?)
            MarkerLayer(
              markers: [
                Marker(
                  point: here,
                  width: 75,
                  height: 75,
                  child: Image.asset('assets/icons/current_location_marker.png'),
                ),
              ],
            ),
          // Only this layer repaints per animation frame.
          ValueListenableBuilder<int>(
            valueListenable: frame,
            builder: (context, _, __) {
              final now = clock.elapsed;
              return MarkerLayer(
                markers: [
                  for (final track in tracks.values)
                    if (track.positionAt(now) case final point?)
                      Marker(
                        point: point,
                        width: 50,
                        height: 50,
                        child: VehicleMarker(
                          vehicle: track.latest,
                          heading: track.headingAt(now),
                        ),
                      ),
                ],
              );
            },
          ),
          MarkerLayer(
            markers: [
              for (final stop in stops)
                Marker(
                  point: stop.location,
                  width: 56,
                  height: 68,
                  alignment: Alignment.topCenter,
                  child: StopImageMarker(
                    stop: stop,
                    onTap: () => showStopDetailsSheet(context, stop),
                  ),
                ),
            ],
          ),
          _ZoomButtons(onZoom: _zoomBy),
        ],
      ),
    );
  }
}

class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({required this.onZoom});

  final ValueChanged<double> onZoom;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Material(
          color: Colors.white,
          elevation: 3,
          borderRadius: BorderRadius.circular(AppRadius.card),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Zoom in',
                icon: const Icon(Icons.add),
                color: AppColors.primary,
                onPressed: () => onZoom(1),
              ),
              const SizedBox(width: 32, child: Divider(height: 1)),
              IconButton(
                tooltip: 'Zoom out',
                icon: const Icon(Icons.remove),
                color: AppColors.primary,
                onPressed: () => onZoom(-1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
