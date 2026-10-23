// lib/widgets/commuter/live_map.dart
//
// Live Map card: OSM tiles locked to the service area, stops (small dots
// when zoomed out, photo pins up close), animated vehicle markers, the
// commuter's location and zoom buttons.
// Owns no state — the Home tab feeds it data and the map controller.
//
// With [selectedVehicleId] set (picked from "Nearby Vehicles") it shows how
// to catch that jeep: the walk from [currentLocation] to [boardAt] along
// [walkPath] (blue dots) and the jeep's route up to that spot ([jeepPath],
// teal). Without a boarding plan it falls back to a straight line from the
// jeep's animated position to the commuter, redrawn every frame.
//
// Stops aren't drawn on their own (too much clutter): only a selected
// [trip]'s stops show, on its line. [showAllStops] brings every stop back.
// With a trip selected only the jeeps in [onlyVehicles] (those on its
// routes) are drawn; every jeep comes back when the trip is cleared.
//
// The commuter is a blue circle ("you are here"), not a pin. While they
// ride a jeep ([ridingVehicleId], see services/ride_matcher.dart) the two
// merge: no circle, just that jeep, larger and ringed in the same blue.
//
// [expanded] draws it edge to edge (the Home tab's full-screen map) instead
// of as a rounded card; [onToggleExpanded] adds the expand / collapse button.

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

  /// Full screen: no card corners, border or shadow.
  final bool expanded;

  /// Shows the expand / collapse button in the map controls.
  final VoidCallback? onToggleExpanded;

  /// False when the parent places [MapControls] itself (e.g. above a sheet).
  final bool showControls;

  /// Space at the top covered by something floating over the map (the
  /// full-screen search bar), so the "Hide line" chip sits below it.
  final double topInset;

  /// The route picked with "Select this route": its lines and stops.
  final TripRouteLayers? trip;

  /// When set, only these jeeps are drawn (a selected trip's routes).
  final Set<String>? onlyVehicles;

  /// Draw every stop (dots zoomed out, photo pins up close). Off on Home.
  final bool showAllStops;

  /// The jeep the commuter is on: drawn as "you", in place of the circle.
  final String? ridingVehicleId;

  static const Color _walkLine = Color(0xFF2F6FED);

  static const Color _selectionLine = AppColors.brandTeal;

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
          if (trip case final trip?) PolylineLayer(polylines: trip.lines),
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
          // Under the vehicles, so a stop never hides a jeep.
          if (showAllStops && trip == null) _StopMarkers(stops: stops),
          if (trip case final trip?) MarkerLayer(markers: trip.markers),
          // Only this layer repaints per animation frame.
          ValueListenableBuilder<int>(
            valueListenable: frame,
            builder: (context, _, __) {
              final now = clock.elapsed;
              return MarkerLayer(
                markers: [
                  for (final track in tracks.values)
                    if (onlyVehicles == null || onlyVehicles!.contains(track.latest.vehicleId))
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

/// Stops, sized for how far out the map is — they only ever get SMALLER as
/// you zoom out, never bigger. Zoomed out, many stops share a few streets,
/// so each is a dot that shrinks with the map. From street level
/// ([photoZoom]) in, they spread out enough for photo pins.
class _StopMarkers extends StatelessWidget {
  const _StopMarkers({required this.stops});

  final List<TransportStop> stops;

  static const double photoZoom = 15;

  /// Dot diameter: 4 px at zoom 11 or further out, up to 10 px at zoom 14.
  static double dotSize(double zoom) => (4 + (zoom - 11) * 2).clamp(4.0, 10.0);

  /// Photo diameter: 18 px at zoom 15, up to the full size at zoom 17.
  static double photoSize(double zoom) =>
      (18 + (zoom - photoZoom) * 5).clamp(18.0, StopImageMarker.maxPhoto);

  @override
  Widget build(BuildContext context) {
    // Rebuilds as the camera moves, so sizes follow the zoom live.
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
              // Bigger than the dot, so it is still easy to tap.
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

class _StopDot extends StatelessWidget {
  const _StopDot({required this.size});

  final double size;

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
          // A thinner ring on the tiniest dots, or it hides the colour.
          border: Border.all(color: Colors.white, width: size >= 8 ? 2 : 1),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
        ),
      ),
    );
  }
}

/// The commuter on the map: a blue dot with a white ring and a soft halo.
/// The ridden jeep stands in for the commuter: drawn only if it's on the map.
extension on LiveMap {
  bool get _ridingShown {
    final id = ridingVehicleId;
    if (id == null || !tracks.containsKey(id)) return false;
    return onlyVehicles == null || onlyVehicles!.contains(id);
  }
}

/// "You are on this jeep": the jeep inside the you-are-here blue ring.
class _RidingMarker extends StatelessWidget {
  const _RidingMarker({required this.child});

  final Widget child;

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
  const _ClearSelectionChip({required this.onPressed, this.topInset = 0});

  final VoidCallback onPressed;
  final double topInset;

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

/// The map's buttons, stacked on the right: expand / collapse (with
/// [onToggleExpanded]), center on my location (with [onLocate]) and zoom.
class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.controller,
    this.expanded = false,
    this.onToggleExpanded,
    this.onLocate,
  });

  final MapController controller;
  final bool expanded;
  final VoidCallback? onToggleExpanded;
  final VoidCallback? onLocate;

  void _zoomBy(double delta) {
    final camera = controller.camera;
    final zoom = (camera.zoom + delta).clamp(MapConfig.minZoom, MapConfig.maxZoom);
    controller.move(camera.center, zoom);
  }

  static Widget _card(Widget child) => Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
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
          _card(IconButton(
            tooltip: 'Center on my location',
            icon: const Icon(Icons.my_location),
            color: AppColors.brandTeal,
            onPressed: onLocate,
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
