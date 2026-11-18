// Driver map
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../providers/driver_provider.dart';
import '../commuter/live_map.dart' show MapControls;
import '../commuter/vehicle_marker.dart';

/// Driver map
class DriverMap extends StatefulWidget {
  /// Create driver map
  const DriverMap({
    super.key,
    required this.driver,
    required this.controller,
    this.expanded = false,
    this.onToggleExpanded,
    this.onLocate,
    this.following,
    this.onMapReady,
    this.onMapEvent,
    this.myLocation,
    this.showControls = true,
  });

  final DriverProvider driver;
  final MapController controller;

  final bool expanded;
  final VoidCallback? onToggleExpanded;

  final VoidCallback? onLocate;
  final ValueListenable<bool>? following;

  final VoidCallback? onMapReady;

  final MapEventCallback? onMapEvent;

  final LatLng? myLocation;

  final bool showControls;

  /// Create widget state
  @override
  State<DriverMap> createState() => _DriverMapState();
}

/// Driver map state
class _DriverMapState extends State<DriverMap> {
  bool _ready = false;
  String? _framedRouteId;

  /// Frame route
  void _frameRoute() {
    final route = widget.driver.route;
    if (!_ready || route == null || route.id == _framedRouteId || route.geometry.length < 2) return;
    if (widget.driver.jeepPosition != null || widget.myLocation != null) return;
    _framedRouteId = route.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.controller.fitCamera(
        CameraFit.coordinates(coordinates: route.geometry, padding: const EdgeInsets.all(32), maxZoom: 16),
      );
    });
  }

  /// Driver map heading
  double? _heading(DriverProvider driver) {
    final live = driver.live;
    if (driver.jeepGps != JeepGps.none && live?.heading != null) return live!.heading;
    final fix = driver.gps.lastFix;
    if (fix == null || fix.speed < 1.5 || fix.heading < 0) return null;
    return fix.heading;
  }

  /// Build the widget
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
            widget.onMapReady?.call();
            _frameRoute();
          },
          onMapEvent: widget.onMapEvent,
          keepAlive: true,
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
            ])
          else if (widget.myLocation case final here?)
            MarkerLayer(markers: [
              Marker(point: here, width: 26, height: 26, child: const _MyLocationDot()),
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
                  onLocate: widget.onLocate,
                  following: widget.following,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Stop dot widget
class _StopDot extends StatelessWidget {
  /// Create stop dot
  const _StopDot();

  /// Build the widget
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

/// My location dot widget
class _MyLocationDot extends StatelessWidget {
  /// Create my location dot
  const _MyLocationDot();

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('driverMyLocation'),
      decoration: BoxDecoration(
        color: const Color(0xFF2F6FED),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
      ),
    );
  }
}

/// Jeep marker
class _JeepMarker extends StatelessWidget {
  /// Create jeep marker
  const _JeepMarker({this.heading});

  final double? heading;

  /// Build the widget
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
