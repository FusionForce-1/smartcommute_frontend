// lib/widgets/commuter/live_map.dart
//
// Live Map card: OSM tiles locked to the service area, stop photo pins,
// animated vehicle markers, the commuter's location and zoom buttons.
// Owns no state — the Home tab feeds it data and the map controller.
//
// With [selectedVehicleId] set (picked from "Nearby Vehicles") it shows how
// to catch that jeep: the walk from [currentLocation] to [boardAt] along
// [walkPath] (blue dots) and the jeep's route up to that spot ([jeepPath],
// teal). Without a boarding plan it falls back to a straight line from the
// jeep's animated position to the commuter, redrawn every frame.
//
// The commuter is a blue circle ("you are here"), not a pin.

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
    this.selectedVehicleId,
    this.onClearSelection,
    this.walkPath,
    this.boardAt,
    this.jeepPath,
  });

  final MapController controller;
  final List<TransportStop> stops;
  final Map<String, VehicleTrack> tracks;

  /// Shared animation clock; [frame] ticks whenever vehicle markers move.
  final Stopwatch clock;
  final ValueNotifier<int> frame;

  final VoidCallback onMapReady;
  final LatLng? currentLocation;

  /// Jeep to draw the "vehicle → you" line from; [onClearSelection] hides it.
  final String? selectedVehicleId;
  final VoidCallback? onClearSelection;

  /// Walk from the commuter to [boardAt] (by road, or straight if unknown).
  final List<LatLng>? walkPath;

  /// Where to wait for the selected jeep.
  final LatLng? boardAt;

  /// The jeep's route from where it is now to [boardAt] (empty once passed).
  final List<LatLng>? jeepPath;

  static const Color _walkLine = Color(0xFF2F6FED);

  static const Color _selectionLine = AppColors.brandTeal;

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
          // North always up: a two-finger twist used to rotate the map with
          // no way back, making every direction look wrong.
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onMapReady: onMapReady,
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            userAgentPackageName: MapConfig.userAgentPackageName,
          ),
          // How to catch the selected jeep: its route to the boarding spot,
          // and the walk there. Under the markers so every end stays visible.
          if (selectedVehicleId != null && walkPath != null)
            PolylineLayer(
              polylines: [
                if (jeepPath case final path? when path.length >= 2)
                  Polyline(
                    points: path,
                    strokeWidth: 6,
                    color: _selectionLine.withValues(alpha: 0.85),
                    borderStrokeWidth: 2,
                    borderColor: Colors.white,
                  ),
                Polyline(
                  points: walkPath!,
                  strokeWidth: 5,
                  color: _walkLine,
                  borderStrokeWidth: 1.5,
                  borderColor: Colors.white,
                  pattern: const StrokePattern.dotted(spacingFactor: 1.6),
                ),
              ],
            )
          // Fallback: vehicle → you, straight, following the jeep.
          else if ((selectedVehicleId, currentLocation) case (final id?, final here?))
            ValueListenableBuilder<int>(
              valueListenable: frame,
              builder: (context, _, __) {
                final from = tracks[id]?.positionAt(clock.elapsed);
                return PolylineLayer(
                  polylines: [
                    if (from != null)
                      Polyline(
                        points: [from, here],
                        strokeWidth: 5,
                        color: _selectionLine,
                        borderStrokeWidth: 2,
                        borderColor: Colors.white,
                        pattern: StrokePattern.dashed(segments: const [14, 8]),
                      ),
                  ],
                );
              },
            ),
          if (selectedVehicleId != null && boardAt != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: boardAt!,
                  width: 34,
                  height: 34,
                  child: const Tooltip(message: 'Wait for the jeep here', child: _BoardHere()),
                ),
              ],
            ),
          if (currentLocation case final here?)
            MarkerLayer(
              markers: [
                Marker(point: here, width: 44, height: 44, child: const _YouAreHere()),
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
          if (selectedVehicleId != null && onClearSelection != null)
            _ClearSelectionChip(onPressed: onClearSelection!),
        ],
      ),
    );
  }
}

/// The commuter on the map: a blue dot with a white ring and a soft halo.
class _YouAreHere extends StatelessWidget {
  const _YouAreHere();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'You are here',
      child: Center(
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: LiveMap._walkLine.withValues(alpha: 0.18),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: LiveMap._walkLine,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where to wait for the selected jeep: a teal-ringed circle with a bus.
class _BoardHere extends StatelessWidget {
  const _BoardHere();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: LiveMap._selectionLine, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.directions_bus, size: 18, color: LiveMap._selectionLine),
    );
  }
}

/// Top-left "✕ Hide line" chip shown while a vehicle is selected.
class _ClearSelectionChip extends StatelessWidget {
  const _ClearSelectionChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: ActionChip(
          avatar: const Icon(Icons.close, size: 18, color: LiveMap._selectionLine),
          label: const Text('Hide line'),
          backgroundColor: Colors.white,
          elevation: 3,
          onPressed: onPressed,
        ),
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
