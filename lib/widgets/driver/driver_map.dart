// lib/widgets/driver/driver_map.dart
//
// The driver's route line and stops with the jeep on top: where the live
// feed puts it (its tracker, or this phone while the tracker is offline),
// else this phone's own fix. The Map tab shows it as a card and full screen
// ([expanded]); the buttons (expand / collapse, centre on the jeep, zoom)
// are the commuter map's MapControls.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../commuter/live_map.dart' show MapControls;
import '../commuter/vehicle_marker.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({
    super.key,
    required this.driver,
    required this.controller,
    this.expanded = false,
    this.onToggleExpanded,
    this.showControls = true,
  });

  final DriverProvider driver;
  final MapController controller;

  /// Full screen: edge to edge, no card corners.
  final bool expanded;
  final VoidCallback? onToggleExpanded;

  /// False when the parent places the controls itself (above a sheet).
  final bool showControls;

  /// Centres the map on the driver's jeep, if we know where it is.
  static void centreOnJeep(DriverProvider driver, MapController controller) {
    final jeep = driver.jeepPosition;
    if (jeep != null) controller.move(jeep, 16);
  }

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  bool _ready = false;
  String? _framedRouteId;

  /// Frames the route once per route, when both it and the map are ready.
  void _frameRoute() {
    final route = widget.driver.route;
    if (!_ready || route == null || route.id == _framedRouteId || route.geometry.length < 2) return;
    _framedRouteId = route.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.fitCamera(
        CameraFit.coordinates(coordinates: route.geometry, padding: const EdgeInsets.all(32), maxZoom: 16),
      );
    });
  }

  /// The course while moving; null while stopped (it swings at random).
  double? _heading(DriverProvider driver) {
    final live = driver.live;
    if (driver.jeepGps != JeepGps.none && live?.heading != null) return live!.heading;
    final fix = driver.gps.lastFix;
    if (fix == null || fix.speed < 1.5 || fix.heading < 0) return null;
    return fix.heading;
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final jeep = driver.jeepPosition;
    final route = driver.route;
    _frameRoute();

    return Container(
      decoration: widget.expanded
          ? const BoxDecoration()
          : BoxDecoration(
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              boxShadow: AppShadows.card,
              border: Border.all(color: AppColors.divider),
            ),
      clipBehavior: Clip.antiAlias,
      child: FlutterMap(
        mapController: widget.controller,
        options: MapOptions(
          initialCenter: jeep ?? MapConfig.defaultCenter,
          initialZoom: jeep != null ? 15 : 13,
          minZoom: MapConfig.minZoom,
          maxZoom: MapConfig.maxZoom,
          cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
          interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          onMapReady: () {
            _ready = true;
            _frameRoute();
          },
        ),
        children: [
          TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: MapConfig.userAgentPackageName),
          if (route != null && route.geometry.length > 1)
            PolylineLayer(polylines: [
              Polyline(points: route.geometry, color: AppColors.brandTeal, strokeWidth: 6),
            ]),
          if (route != null)
            MarkerLayer(markers: [
              for (final stop in route.stops)
                Marker(point: stop.location, width: 18, height: 18, child: const _StopDot()),
            ]),
          if (jeep != null)
            MarkerLayer(markers: [
              Marker(point: jeep, width: 44, height: 44, child: _JeepMarker(heading: _heading(driver))),
            ]),
          if (widget.showControls)
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: MapControls(
                  controller: widget.controller,
                  expanded: widget.expanded,
                  onToggleExpanded: widget.onToggleExpanded,
                  onLocate: jeep == null ? null : () => DriverMap.centreOnJeep(driver, widget.controller),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A route stop: white with a thick teal ring.
class _StopDot extends StatelessWidget {
  const _StopDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brandTeal, width: 4),
      ),
    );
  }
}

/// The driver's PUV, facing the way it is driving.
class _JeepMarker extends StatelessWidget {
  const _JeepMarker({this.heading});

  final double? heading;

  @override
  Widget build(BuildContext context) {
    Widget puv = SvgPicture.asset(VehicleMarker.asset, width: 36, height: 36);
    if (heading != null) puv = Transform.rotate(angle: heading! * math.pi / 180, child: puv);
    return Container(
      key: const Key('driverJeep'),
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: puv,
    );
  }
}
