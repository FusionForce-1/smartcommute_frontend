// lib/screens/driver/driver_route_map_screen.dart
//
// The driver's route line and stops with their own position on top.
// Opened from "View My Route on Map" and, while sharing, from
// "View Live Broadcast" (which starts centred on the driver).
// Watches DriverProvider, so the position and next stop stay live.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/transport_model.dart';
import '../../providers/driver_provider.dart';
import '../../services/driver_service.dart';
import '../../services/websocket_service.dart';
import '../../utils/shift_time.dart';
import '../../widgets/commuter/commuter_page_header.dart';

class DriverRouteMapScreen extends StatefulWidget {
  const DriverRouteMapScreen({super.key, required this.service, this.followMe = false});

  final DriverService service;

  /// Start centred on the driver instead of fitting the whole route.
  final bool followMe;

  @override
  State<DriverRouteMapScreen> createState() => _DriverRouteMapScreenState();
}

class _DriverRouteMapScreenState extends State<DriverRouteMapScreen> {
  final _map = MapController();
  TransportRoute? _route;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final routeId = context.read<DriverProvider>().vehicle?.routeId;
    TransportRoute? route;
    if (routeId != null && routeId.isNotEmpty) {
      try {
        route = await widget.service.route(routeId);
      } catch (_) {
        route = null; // no map line yet: show the driver's position only
      }
    }
    if (!mounted) return;
    setState(() {
      _route = route;
      _loading = false;
    });
  }

  LatLng? _myPosition(DriverProvider driver) {
    final fix = driver.gps.lastFix;
    if (fix != null) return LatLng(fix.latitude, fix.longitude);
    return driver.live?.location;
  }

  MapOptions _options(LatLng? me) {
    final line = _route?.geometry ?? const <LatLng>[];
    final fitRoute = !widget.followMe && line.length > 1;
    return MapOptions(
      initialCenter: me ?? (line.isNotEmpty ? line.first : MapConfig.defaultCenter),
      initialZoom: me != null ? 16 : 13,
      initialCameraFit: fitRoute
          ? CameraFit.coordinates(coordinates: line, padding: const EdgeInsets.all(40), maxZoom: 16)
          : null,
      minZoom: MapConfig.minZoom,
      maxZoom: MapConfig.maxZoom,
      cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = context.watch<DriverProvider>();
    final me = _myPosition(driver);
    final route = _route;

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          CommuterPageHeader(title: widget.followMe ? 'Live Broadcast' : 'My Route'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Stack(
                    children: [
                      FlutterMap(
                        mapController: _map,
                        options: _options(me),
                        children: [
                          TileLayer(
                            urlTemplate: MapConfig.tileUrl,
                            userAgentPackageName: MapConfig.userAgentPackageName,
                          ),
                          if (route != null && route.geometry.length > 1)
                            PolylineLayer(polylines: [
                              Polyline(points: route.geometry, color: AppColors.brandTeal, strokeWidth: 5),
                            ]),
                          if (route != null)
                            MarkerLayer(markers: [
                              for (final stop in route.stops)
                                Marker(
                                  point: stop.location,
                                  width: 14,
                                  height: 14,
                                  child: const _StopDot(),
                                ),
                            ]),
                          if (me != null)
                            MarkerLayer(markers: [
                              Marker(point: me, width: 44, height: 44, child: const _MeMarker()),
                            ]),
                        ],
                      ),
                      if (me != null)
                        Positioned(
                          right: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: FloatingActionButton.small(
                            heroTag: null,
                            tooltip: 'Centre on me',
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.brandTeal,
                            onPressed: () => _map.move(me, 16),
                            child: const Icon(Icons.my_location),
                          ),
                        ),
                    ],
                  ),
          ),
          _InfoPanel(driver: driver, hasRouteLine: route != null),
        ],
      ),
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

class _MeMarker extends StatelessWidget {
  const _MeMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.infoBlue.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.navigation, color: AppColors.infoBlue, size: 26),
    );
  }
}

/// Route, broadcast state, and next stop / ETA under the map.
class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.driver, required this.hasRouteLine});

  final DriverProvider driver;
  final bool hasRouteLine;

  String get _broadcast => switch (driver.gps.state) {
        GpsSessionState.live => 'Sharing your location',
        GpsSessionState.connecting || GpsSessionState.reconnecting => 'Connecting…',
        GpsSessionState.error => driver.gps.error ?? 'GPS stopped',
        _ => driver.onShift ? 'Location sharing is off' : 'Start your shift to share your location',
      };

  @override
  Widget build(BuildContext context) {
    final vehicle = driver.vehicle;
    final live = driver.live;
    const label = TextStyle(fontSize: 14, color: AppColors.textSecondary);
    const value = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

    Widget row(String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Text(l, style: label),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(v, style: value, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
          ]),
        );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                vehicle == null ? 'No vehicle assigned' : '${vehicle.routeCode ?? 'Route'} · ${vehicle.routeLine}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              if (!hasRouteLine)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('This route has no map line yet.', style: label),
                ),
              const SizedBox(height: AppSpacing.xs),
              row('GPS', _broadcast),
              row('Next stop', live?.nextStop ?? '—'),
              row('ETA', formatEta(live?.etaNextStop)),
            ],
          ),
        ),
      ),
    );
  }
}
