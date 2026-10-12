// lib/screens/commuter/home.dart
//
// Home tab: destination search, Live Map, quick actions and the
// "Nearby Vehicles" list. Opens the live vehicle socket and animates
// one smoothed track per jeep.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../models/vehicle_live_update.dart';
import '../../models/vehicle_track.dart';
import '../../models/vehicles.dart';
import '../../services/websocket_service.dart';
import '../../widgets/commuter/commuter_action_tile.dart';
import '../../widgets/commuter/live_map.dart';
import '../../widgets/commuter/nearby_vehicle_card.dart';
import '../../widgets/stop_image.dart';
import '../../widgets/stop_search_sheet.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    required this.stops,
    required this.routes,
    required this.vehicles,
  });

  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  /// Fleet list from /vehicles, used to tell which route a live jeep is on.
  final List<Vehicle> vehicles;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  static const int _maxNearby = 5;

  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _currentLocation;

  // One smoothed track per jeep, so several vehicles broadcasting at once
  // each keep their own marker.
  final Map<String, VehicleTrack> _tracks = {};

  // Drives marker animation: only the vehicle layer repaints per frame,
  // and the ticker stops once every marker has reached its latest fix.
  final Stopwatch _clock = Stopwatch()..start();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;

  // Bumped per socket message, so "Nearby Vehicles" rebuilds on new
  // data instead of on every animation frame.
  final ValueNotifier<int> _fleetVersion = ValueNotifier(0);

  late final WebSocketService _socket;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _socket = WebSocketService()
      ..connect()
      ..listenForMessages(_onVehicleMessage);
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops.isEmpty && widget.stops.isNotEmpty) _fitToStops();
  }

  @override
  void dispose() {
    _socket.disconnect();
    _ticker.dispose();
    _frame.dispose();
    _fleetVersion.dispose();
    super.dispose();
  }

  // ---------- Live vehicles ----------

  void _onVehicleMessage(dynamic message) {
    if (!mounted) return;

    final update = VehicleLiveUpdate.fromJson(
      jsonDecode(message as String) as Map<String, dynamic>,
    );
    final now = _clock.elapsed;
    final track = _tracks[update.vehicleId];
    if (track == null) {
      _tracks[update.vehicleId] = VehicleTrack(update, now);
    } else {
      track.push(update, now); // drops out-of-order fixes and GPS glitches
    }

    _frame.value++;
    _fleetVersion.value++;
    if (!_ticker.isActive) _ticker.start();
  }

  void _onTick(Duration _) {
    _frame.value++;
    if (!_tracks.values.any((t) => t.isAnimating(_clock.elapsed))) _ticker.stop();
  }

  void _refreshVehicles() {
    _tracks.clear();
    _frame.value++;
    _fleetVersion.value++;
    _socket.connect();
  }

  /// Live jeeps on a known route, nearest first (or soonest, without GPS).
  List<({TransportRoute route, VehicleLiveUpdate update})> _nearbyVehicles() {
    final routesById = {for (final r in widget.routes) r.id: r};
    final routeByVehicle = {
      for (final v in widget.vehicles) v.id: routesById[v.routeId],
    };

    final live = [
      for (final track in _tracks.values)
        if (!track.latest.isSignalLost && track.latest.location != null)
          if (routeByVehicle[track.latest.vehicleId] case final route?)
            (route: route, update: track.latest),
    ];

    final here = _currentLocation;
    if (here != null) {
      const distance = Distance();
      double metresTo(VehicleLiveUpdate u) => distance.as(LengthUnit.Meter, here, u.location!);
      live.sort((a, b) => metresTo(a.update).compareTo(metresTo(b.update)));
    } else {
      int eta(VehicleLiveUpdate u) => _etaMinutes(u) ?? 1 << 30;
      live.sort((a, b) => eta(a.update).compareTo(eta(b.update)));
    }
    return live.take(_maxNearby).toList();
  }

  int? _etaMinutes(VehicleLiveUpdate update) {
    final eta = update.etaNextStop;
    return eta != null && eta >= 0 ? eta : null;
  }

  // ---------- Map ----------

  void _onMapReady() {
    _mapReady = true;
    _fitToStops();
  }

  void _fitToStops() {
    final stops = widget.stops;
    if (!_mapReady || stops.isEmpty) return;
    if (stops.length == 1) {
      _mapController.move(stops.first.location, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: stops.map((stop) => stop.location).toList(),
        padding: const EdgeInsets.all(48),
        maxZoom: 16,
      ),
    );
  }

  Future<void> _searchDestination() async {
    if (widget.stops.isEmpty) {
      _showMessage('Stops are still loading. Please try again in a moment.');
      return;
    }
    final stop = await showStopSearchSheet(context, widget.stops);
    if (stop == null || !mounted) return;
    _mapController.move(stop.location, 16);
    showStopDetailsSheet(context, stop);
  }

  Future<void> _centerOnMyLocation() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Location permission was not granted.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final here = LatLng(position.latitude, position.longitude);
      setState(() => _currentLocation = here);
      _fleetVersion.value++; // re-sort "Nearby Vehicles" by distance
      _mapController.move(here, 15);
    } catch (_) {
      _showMessage('Unable to get your current location.');
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SearchField(onTap: _searchDestination),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 320,
          child: LiveMap(
            controller: _mapController,
            stops: widget.stops,
            tracks: _tracks,
            clock: _clock,
            frame: _frame,
            currentLocation: _currentLocation,
            onMapReady: _onMapReady,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        CommuterActionTile(
          icon: AppIcons.myLocation,
          label: 'Center on my location',
          onTap: _centerOnMyLocation,
        ),
        CommuterActionTile(
          icon: AppIcons.vehicle,
          label: 'Refresh vehicle markers',
          onTap: _refreshVehicles,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Nearby Vehicles',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: AppSpacing.sm),
        ValueListenableBuilder<int>(
          valueListenable: _fleetVersion,
          builder: (context, _, __) => _NearbyList(
            vehicles: _nearbyVehicles(),
            etaOf: _etaMinutes,
          ),
        ),
      ],
    );
  }
}

/// Looks like a text field; opens the stop search sheet when tapped.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(color: AppColors.divider, width: 1.4),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(AppIcons.search, color: AppColors.navInactive),
              SizedBox(width: 12),
              Text(
                'Search destination...',
                style: TextStyle(fontSize: 16, color: AppColors.navInactive),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList({required this.vehicles, required this.etaOf});

  final List<({TransportRoute route, VehicleLiveUpdate update})> vehicles;
  final int? Function(VehicleLiveUpdate) etaOf;

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text('No vehicles nearby right now.'),
      );
    }
    return Column(
      children: [
        for (final v in vehicles)
          NearbyVehicleCard(
            routeCode: v.route.code,
            routeName: v.route.name,
            etaMinutes: etaOf(v.update),
          ),
      ],
    );
  }
}
