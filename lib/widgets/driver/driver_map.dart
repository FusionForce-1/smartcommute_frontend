// lib/widgets/driver/driver_map.dart
//
// The driver's route line and stops with the jeep on top: where the live
// feed puts it (its tracker, or this phone while the tracker is offline),
// else this phone's own fix. Used on the dashboard and full screen.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../providers/driver_provider.dart';
import '../commuter/vehicle_marker.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({super.key, required this.driver, this.onExpand});

  final DriverProvider driver;

  /// Adds a full-screen button (the dashboard's small map).
  final VoidCallback? onExpand;

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  final _map = MapController();
  TransportRoute? _route;
  String? _routeId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  @override
  void didUpdateWidget(DriverMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.driver.vehicle?.routeId != _routeId) _loadRoute();
  }

  /// Called from initState / didUpdateWidget, which rebuild anyway: the
  /// fields are set directly until the first await.
  Future<void> _loadRoute() async {
    final routeId = widget.driver.vehicle?.routeId;
    _routeId = routeId;
    _route = null;
    if (routeId == null || routeId.isEmpty) return;
    _loading = true;
    final route = await widget.driver.routeLine(routeId);   // null: no map line yet, show the jeep only
    if (!mounted || routeId != _routeId) return;
    setState(() {
      _route = route;
      _loading = false;
    });
    final line = route?.geometry ?? const <LatLng>[];
    if (line.length < 2) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _map.fitCamera(CameraFit.coordinates(coordinates: line, padding: const EdgeInsets.all(32), maxZoom: 16));
    });
  }

  LatLng? _jeep(DriverProvider driver) {
    if (driver.jeepGps != JeepGps.none) return driver.live?.location;
    final fix = driver.gps.lastFix;
    return fix == null ? driver.live?.location : LatLng(fix.latitude, fix.longitude);
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
    final jeep = _jeep(driver);
    final heading = _heading(driver);
    final route = _route;

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: jeep ?? MapConfig.defaultCenter,
            initialZoom: jeep != null ? 15 : 13,
            minZoom: MapConfig.minZoom,
            maxZoom: MapConfig.maxZoom,
            cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
          ),
          children: [
            TileLayer(urlTemplate: MapConfig.tileUrl, userAgentPackageName: MapConfig.userAgentPackageName),
            if (route != null && route.geometry.length > 1)
              PolylineLayer(polylines: [
                Polyline(points: route.geometry, color: AppColors.brandTeal, strokeWidth: 5),
              ]),
            if (route != null)
              MarkerLayer(markers: [
                for (final stop in route.stops)
                  Marker(point: stop.location, width: 14, height: 14, child: const _StopDot()),
              ]),
            if (jeep != null)
              MarkerLayer(markers: [
                Marker(point: jeep, width: 44, height: 44, child: _JeepMarker(heading: heading)),
              ]),
          ],
        ),
        if (_loading) const Positioned(top: 8, left: 8, child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        Positioned(
          right: AppSpacing.xs,
          bottom: AppSpacing.xs,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onExpand != null)
                _MapButton(tooltip: 'Full screen', icon: Icons.open_in_full, onPressed: widget.onExpand!),
              if (jeep != null) ...[
                const SizedBox(height: 6),
                _MapButton(tooltip: 'Centre on the jeep', icon: Icons.my_location, onPressed: () => _map.move(jeep, 16)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.tooltip, required this.icon, required this.onPressed});

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: tooltip,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.brandTeal,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}

class _StopDot extends StatelessWidget {
  const _StopDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brandTeal, width: 3),
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
