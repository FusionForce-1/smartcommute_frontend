// Pick destination screen
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/transport_stop.dart';
import '../../services/nearest_stop.dart';

typedef PickedPlace = ({LatLng point, String label});

/// Initial pick center
LatLng initialPickCenter(LatLng? origin) {
  if (origin != null && MapConfig.serviceArea.contains(origin)) return origin;
  return MapConfig.defaultCenter;
}

/// Pinned label
String pinnedLabel(LatLng point, List<TransportStop> stops) {
  final near = nearestStop(stops, point);
  if (near != null) return 'Pinned spot · near ${near.stop.name}';
  return 'Pinned spot (${point.latitude.toStringAsFixed(4)}, '
      '${point.longitude.toStringAsFixed(4)})';
}

/// Pick destination screen
class PickDestinationScreen extends StatefulWidget {
  /// Create pick destination
  const PickDestinationScreen({
    super.key,
    this.origin,
    this.stops = const [],
    this.start,
  });

  final LatLng? origin;
  final List<TransportStop> stops;

  final LatLng? start;

  /// Create widget state
  @override
  State<PickDestinationScreen> createState() => _PickDestinationScreenState();
}

/// Pick destination state
class _PickDestinationScreenState extends State<PickDestinationScreen> {
  final MapController _mapController = MapController();
  late LatLng _center = initialPickCenter(widget.start ?? widget.origin);
  bool _moving = false;
  Timer? _settle;

  /// Clean up resources
  @override
  void dispose() {
    _settle?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// On moved
  void _onMoved(MapCamera camera, bool hasGesture) {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 220), () {
      if (mounted) setState(() => _moving = false);
    });
    setState(() {
      _center = camera.center;
      _moving = true;
    });
  }

  /// Back to start
  void _backToStart() {
    final origin = widget.origin;
    if (origin == null) return;
    _mapController.move(initialPickCenter(origin), 16);
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final origin = widget.origin;
    final near = nearestStop(widget.stops, _center);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brandTeal,
        foregroundColor: Colors.white,
        title: const Text('Pick destination'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 15,
              minZoom: MapConfig.minZoom,
              maxZoom: MapConfig.maxZoom,
              cameraConstraint: CameraConstraint.contain(
                bounds: MapConfig.mapBounds,
              ),
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: _onMoved,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.userAgentPackageName,
              ),
              CircleLayer(
                circles: [
                  for (final stop in widget.stops)
                    CircleMarker(
                      point: stop.location,
                      radius: 4,
                      color: AppColors.secondary,
                      borderColor: Colors.white,
                      borderStrokeWidth: 1.5,
                    ),
                  if (origin != null)
                    CircleMarker(
                      point: origin,
                      radius: 8,
                      color: AppColors.success,
                      borderColor: Colors.white,
                      borderStrokeWidth: 3,
                    ),
                ],
              ),
            ],
          ),
          IgnorePointer(
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _moving ? 8 : 14,
                height: _moving ? 4 : 6,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: _moving ? 0.18 : 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: AnimatedPadding(
                key: const Key('pickPin'),
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: _moving ? 72 : 48),
                child: const Icon(Icons.location_pin, size: 48, color: AppColors.error),
              ),
            ),
          ),
          if (origin != null)
            Positioned(
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: 'Back to my start',
                  icon: const Icon(Icons.my_location, color: AppColors.brandTeal),
                  onPressed: _backToStart,
                ),
              ),
            ),
          Positioned(
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: SafeArea(
              child: Material(
                color: Colors.white,
                elevation: 6,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_pin, color: AppColors.error),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.centerLeft,
                                children: [...previous, if (current != null) current],
                              ),
                              child: Column(
                                key: ValueKey(near?.stop.id),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    near != null ? 'Near ${near.stop.name}' : 'No stop nearby',
                                    key: const Key('pickPlaceName'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    near != null
                                        ? '${formatMetres(near.metres)} from the pin'
                                        : '${_center.latitude.toStringAsFixed(4)}, '
                                            '${_center.longitude.toStringAsFixed(4)}',
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.brandTeal,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () {
                          final point = _mapController.camera.center;
                          Navigator.of(context).pop<PickedPlace>(
                            (point: point, label: pinnedLabel(point, widget.stops)),
                          );
                        },
                        icon: const Icon(Icons.check),
                        label: const Text('Set destination'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
