// Live map
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/transport_stop.dart';
import '../../models/vehicle_track.dart';
import '../stop_image.dart';
import 'trip_route_layers.dart';
import 'vehicle_marker.dart';

/// Live map
class LiveMap extends StatelessWidget {
  /// Create live map
  const LiveMap({
    super.key,
    required this.controller,
    required this.stops,
    required this.tracks,
    required this.clock,
    required this.frame,
    required this.onMapReady,
    this.onMapEvent,
    this.onLocate,
    this.following,
    this.currentLocation,
    this.selectedVehicleId,
    this.onClearSelection,
    this.walkPath,
    this.boardAt,
    this.jeepPath,
    this.expanded = false,
    this.onToggleExpanded,
    this.showControls = true,
    this.topInset = 0,
    this.trip,
    this.onlyVehicles,
    this.showAllStops = false,
    this.ridingVehicleId,
  });

  final MapController controller;
  final List<TransportStop> stops;
  final Map<String, VehicleTrack> tracks;

  final Stopwatch clock;
  final ValueNotifier<int> frame;

  final VoidCallback onMapReady;

  final MapEventCallback? onMapEvent;

  final VoidCallback? onLocate;
  final ValueListenable<bool>? following;

  final LatLng? currentLocation;

  final String? selectedVehicleId;
  final VoidCallback? onClearSelection;

  final List<LatLng>? walkPath;

  final LatLng? boardAt;

  final List<LatLng>? jeepPath;

  final bool expanded;

  final VoidCallback? onToggleExpanded;

  final bool showControls;

  final double topInset;

  final TripRouteLayers? trip;

  final Set<String>? onlyVehicles;

  final bool showAllStops;

  final String? ridingVehicleId;

  static const Color _walkLine = Color(0xFF2F6FED);

  static const Color _selectionLine = AppColors.brandTeal;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: expanded
          ? const BoxDecoration()
          : BoxDecoration(
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
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
          onMapReady: onMapReady,
          onMapEvent: onMapEvent,
          keepAlive: true,
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            userAgentPackageName: MapConfig.userAgentPackageName,
          ),
          if (trip case final trip?) PolylineLayer(polylines: trip.lines),
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
                  child: const Tooltip(message: 'Wait for the PUV here', child: _BoardHere()),
                ),
              ],
            ),
          if (currentLocation case final here? when !_ridingShown)
            MarkerLayer(
              markers: [
                Marker(point: here, width: 44, height: 44, child: const _YouAreHere()),
              ],
            ),
          if (showAllStops && trip == null) _StopMarkers(stops: stops),
          if (trip case final trip?) MarkerLayer(markers: trip.markers),
          ValueListenableBuilder<int>(
            valueListenable: frame,
            builder: (context, _, __) {
              final now = clock.elapsed;
              return MarkerLayer(
                markers: [
                  for (final track in tracks.values)
                    if (onlyVehicles == null || onlyVehicles!.contains(track.latest.vehicleId))
                      if (!track.latest.isOffRoute || track.latest.vehicleId == ridingVehicleId)
                      if (track.positionAt(now) case final point?)
                        track.latest.vehicleId == ridingVehicleId
                            ? Marker(
                                point: point,
                                width: 64,
                                height: 64,
                                child: _RidingMarker(
                                  child: VehicleMarker(vehicle: track.latest, heading: track.headingAt(now)),
                                ),
                              )
                            : Marker(
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
          if (showControls)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: MapControls(
                  controller: controller,
                  expanded: expanded,
                  onToggleExpanded: onToggleExpanded,
                  onLocate: onLocate,
                  following: following,
                ),
              ),
            ),
          if (selectedVehicleId != null && onClearSelection != null)
            _ClearSelectionChip(onPressed: onClearSelection!, topInset: topInset),
        ],
      ),
    );
  }
}

/// Stop markers widget
class _StopMarkers extends StatelessWidget {
  /// Create stop markers
  const _StopMarkers({required this.stops});

  final List<TransportStop> stops;

  static const double photoZoom = 15;

  /// Dot size
  static double dotSize(double zoom) => (4 + (zoom - 11) * 2).clamp(4.0, 10.0);

  /// Photo size
  static double photoSize(double zoom) =>
      (18 + (zoom - photoZoom) * 5).clamp(18.0, StopImageMarker.maxPhoto);

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final photo = photoSize(zoom);
    final dot = dotSize(zoom);
    return MarkerLayer(
      markers: [
        for (final stop in stops)
          if (zoom >= photoZoom)
            Marker(
              point: stop.location,
              width: StopImageMarker.widthFor(photo),
              height: StopImageMarker.heightFor(photo),
              alignment: Alignment.topCenter,
              child: StopImageMarker(
                stop: stop,
                photo: photo,
                onTap: () => showStopDetailsSheet(context, stop),
              ),
            )
          else
            Marker(
              point: stop.location,
              width: 20,
              height: 20,
              child: GestureDetector(
                onTap: () => showStopDetailsSheet(context, stop),
                child: Tooltip(message: stop.name, child: _StopDot(size: dot)),
              ),
            ),
      ],
    );
  }
}

/// Stop dot widget
class _StopDot extends StatelessWidget {
  /// Create stop dot
  const _StopDot({required this.size});

  final double size;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        key: const Key('stopDot'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.secondary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: size >= 8 ? 2 : 1),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
    );
  }
}

/// Live map extension
extension on LiveMap {
  bool get _ridingShown {
    final id = ridingVehicleId;
    if (id == null || !tracks.containsKey(id)) return false;
    return onlyVehicles == null || onlyVehicles!.contains(id);
  }
}

/// Riding marker
class _RidingMarker extends StatelessWidget {
  /// Create riding marker
  const _RidingMarker({required this.child});

  final Widget child;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "You're on this PUV",
      child: Container(
        key: const Key('ridingMarker'),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: LiveMap._walkLine.withValues(alpha: 0.18),
          border: Border.all(color: LiveMap._walkLine, width: 3),
        ),
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}

/// You are here widget
class _YouAreHere extends StatelessWidget {
  /// Create you are here
  const _YouAreHere();

  /// Build the widget
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

/// Board here widget
class _BoardHere extends StatelessWidget {
  /// Create board here
  const _BoardHere();

  /// Build the widget
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

/// Clear selection chip
class _ClearSelectionChip extends StatelessWidget {
  /// Create clear selection chip
  const _ClearSelectionChip({required this.onPressed, this.topInset = 0});

  final VoidCallback onPressed;
  final double topInset;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs).copyWith(top: AppSpacing.xs + topInset),
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

/// Map controls widget
class MapControls extends StatelessWidget {
  /// Create map controls
  const MapControls({
    super.key,
    required this.controller,
    this.expanded = false,
    this.onToggleExpanded,
    this.onLocate,
    this.following,
  });

  final MapController controller;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onLocate;
  final ValueListenable<bool>? following;

  /// Zoom by
  void _zoomBy(double delta) {
    final camera = controller.camera;
    final zoom = (camera.zoom + delta).clamp(MapConfig.minZoom, MapConfig.maxZoom);
    controller.move(camera.center, zoom);
  }

  /// Map controls card
  static Widget _card(Widget child) => Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  /// Locate button
  Widget _locateButton({required bool on}) => IconButton(
        tooltip: 'Center on my location',
        icon: Icon(on ? Icons.my_location : Icons.location_searching),
        color: AppColors.brandTeal,
        onPressed: onLocate,
      );

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final following = this.following;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (onToggleExpanded != null) ...[
          _card(IconButton(
            key: const Key('mapExpandToggle'),
            tooltip: expanded ? 'Exit full screen' : 'Full screen map',
            icon: Icon(expanded ? Icons.close_fullscreen : Icons.open_in_full),
            color: AppColors.brandTeal,
            onPressed: onToggleExpanded,
          )),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (onLocate != null) ...[
          _card(following == null
              ? _locateButton(on: true)
              : ValueListenableBuilder<bool>(
                  valueListenable: following,
                  builder: (context, on, _) => _locateButton(on: on),
                )),
          const SizedBox(height: AppSpacing.xs),
        ],
        _card(Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom in',
              icon: const Icon(Icons.add),
              color: AppColors.primary,
              onPressed: () => _zoomBy(1),
            ),
            const SizedBox(width: 32, child: Divider(height: 1)),
            IconButton(
              tooltip: 'Zoom out',
              icon: const Icon(Icons.remove),
              color: AppColors.primary,
              onPressed: () => _zoomBy(-1),
            ),
          ],
        )),
      ],
    );
  }
}
