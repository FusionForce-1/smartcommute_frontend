// lib/screens/commuter/home.dart
//
// Home tab: destination search, Live Map, quick actions and the
// "Nearby Vehicles" list. Opens the live vehicle socket and animates
// one smoothed track per jeep.
//
// The map can go full screen (expand button on the map): it then fills the
// tab with the search bar floating on top, its buttons on the right, and
// "Nearby Vehicles" in a sheet that drags up, or down to just its handle.
// The same map (camera, live jeeps, selection) moves between the two layouts.
//
// Picking a jeep in the "Nearby Vehicles" list shows how to catch it: the closest
// point on its route to the commuter (the shortest walk), the walking path
// there with distance, steps and minutes, and how far the jeep still is
// from that point (services/boarding_planner.dart).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
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
import '../../services/boarding_planner.dart';
import '../../services/place_search.dart';
import '../../services/walking_route_service.dart';
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
    this.onUnknownVehicle,
    this.onRefresh,
  });

  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  /// Fleet list from /vehicles, used to tell which route a live jeep is on.
  final List<Vehicle> vehicles;

  /// A live jeep isn't in [vehicles] / [routes] (added after they loaded):
  /// asks the dashboard to load them again.
  final VoidCallback? onUnknownVehicle;

  /// "Refresh vehicle markers": reload stops, routes and vehicles now.
  final VoidCallback? onRefresh;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  static const int _maxNearby = 5;

  /// Phone fixes with a reported error above this (metres) are ignored.
  static const double _maxFixErrorM = 25;

  final MapController _mapController = MapController();
  bool _mapReady = false;
  LatLng? _currentLocation;

  // Keeps the "you are here" marker following the phone as it moves.
  StreamSubscription<Position>? _positionSub;
  LatLng? _lastSortedAt; // where "Nearby Vehicles" was last sorted from

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

  /// The jeep picked from "Nearby Vehicles"; we show how to catch it.
  String? _selectedVehicleId;

  // How to catch the selected jeep (null until we know where both are).
  BoardingPlan? _plan;
  WalkingRoute? _walk;
  String? _boardName;            // "near Fuente BRT Station"

  // ---------- Full-screen map ----------

  bool _mapExpanded = false;

  /// Keeps the one map (and its controller) alive as it moves between the
  /// card layout and the full-screen layout.
  final GlobalKey _mapKey = GlobalKey();

  final DraggableScrollableController _sheet = DraggableScrollableController();

  /// How much of the full-screen height the sheet covers; the map buttons
  /// ride just above it.
  final ValueNotifier<double> _sheetExtent = ValueNotifier(0);

  static const double _sheetOpen = 0.34;
  static const double _sheetMax = 0.75;

  /// Height of the sheet's drag handle: all that shows when minimized.
  static const double _sheetHandle = 30;
  LatLng? _walkPlannedTo;        // boarding spot the current _walk leads to
  LatLng? _walkPlannedFrom;
  DateTime _lastPlanAt = DateTime.fromMillisecondsSinceEpoch(0);
  final WalkingRouteService _walking = WalkingRouteService();

  late final WebSocketService _socket;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _socket = WebSocketService()
      ..connect()
      ..listenForMessages(_onVehicleMessage);
    _followIfAllowed();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stops.isEmpty && widget.stops.isNotEmpty) _fitToStops();
    // New vehicle / route lists: jeeps that were hidden may now be listed.
    if (!identical(oldWidget.vehicles, widget.vehicles) || !identical(oldWidget.routes, widget.routes)) {
      _fleetVersion.value++;
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _socket.disconnect();
    _ticker.dispose();
    _frame.dispose();
    _fleetVersion.dispose();
    _sheet.dispose();
    _sheetExtent.dispose();
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
    // A jeep we can't place on a route is new to us: reload the lists so it
    // shows up in Nearby Vehicles without restarting the app.
    if (update.location != null && _routeOf(update.vehicleId) == null) widget.onUnknownVehicle?.call();
    // The selected jeep moved: refresh how far it is from the boarding spot.
    if (update.vehicleId == _selectedVehicleId &&
        DateTime.now().difference(_lastPlanAt) > const Duration(seconds: 3)) {
      _updateBoarding();
    }
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
    widget.onRefresh?.call();   // also pick up jeeps / routes added since the app opened
  }

  /// Available live jeeps on a known route, nearest first (or soonest,
  /// without GPS). Signal-lost jeeps and drivers set to Unavailable are left
  /// out: they can't be boarded.
  List<NearbyVehicle> _nearbyVehicles({int limit = _maxNearby}) {
    final routesById = {for (final r in widget.routes) r.id: r};
    final routeByVehicle = {
      for (final v in widget.vehicles) v.id: routesById[v.routeId],
    };

    final here = _currentLocation;
    const distance = Distance();
    final live = [
      for (final track in _tracks.values)
        if (!track.latest.isSignalLost && !track.latest.isUnavailable && track.latest.location != null)
          if (routeByVehicle[track.latest.vehicleId] case final route?)
            (
              route: route,
              update: track.latest,
              metres: here == null ? null : distance.as(LengthUnit.Meter, here, track.latest.location!),
            ),
    ];

    if (here != null) {
      live.sort((a, b) => a.metres!.compareTo(b.metres!));
    } else {
      int eta(VehicleLiveUpdate u) => _etaMinutes(u) ?? 1 << 30;
      live.sort((a, b) => eta(a.update).compareTo(eta(b.update)));
    }
    return live.take(limit).toList();
  }

  // ---------- Nearby Vehicles → line on the map ----------

  /// A jeep tapped in the list: makes sure we know where the commuter is
  /// (the walking line starts there), then shows how to catch it.
  Future<void> _pickNearbyVehicle(String vehicleId) async {
    if (_selectedVehicleId != vehicleId && _currentLocation == null && await _locate() == null) return;
    if (mounted) _selectVehicle(vehicleId);
  }

  /// Shows (or, tapped again, hides) how to catch [vehicleId], framing the
  /// jeep, the commuter and the boarding spot on the map.
  void _selectVehicle(String vehicleId) {
    if (_selectedVehicleId == vehicleId) return _clearSelectedVehicle();
    setState(() {
      _selectedVehicleId = vehicleId;
      _plan = null;
      _walk = null;
      _boardName = null;
      _walkPlannedTo = null;
    });
    final from = _tracks[vehicleId]?.positionAt(_clock.elapsed);
    final to = _currentLocation;
    if (!_mapReady || from == null) return;
    if (to == null) {
      _showMessage('Turn on location to see how to reach this vehicle.');
      _mapController.move(from, 16);
      return;
    }
    _updateBoarding();
    _mapController.fitCamera(CameraFit.coordinates(
      coordinates: [from, to, if (_plan != null) _plan!.boardAt],
      padding: const EdgeInsets.all(56),
      maxZoom: 17,
    ));
  }

  void _clearSelectedVehicle() => setState(() {
        _selectedVehicleId = null;
        _plan = null;
        _walk = null;
        _boardName = null;
        _walkPlannedTo = null;
      });

  TransportRoute? _routeOf(String vehicleId) {
    for (final v in widget.vehicles) {
      if (v.id != vehicleId) continue;
      for (final r in widget.routes) {
        if (r.id == v.routeId) return r;
      }
    }
    return null;
  }

  /// Recomputes where to board the selected jeep; fetches a new walking
  /// path only when the commuter or the boarding spot moved noticeably.
  void _updateBoarding() {
    final id = _selectedVehicleId;
    final here = _currentLocation;
    final jeep = id == null ? null : _tracks[id]?.positionAt(_clock.elapsed);
    if (id == null || here == null || jeep == null) return;
    _lastPlanAt = DateTime.now();
    final plan = planBoarding(route: _routeOf(id)?.geometry ?? const [], user: here, jeep: jeep);
    setState(() => _plan = plan);

    const distance = Distance();
    final movedSpot = _walkPlannedTo == null || distance.as(LengthUnit.Meter, _walkPlannedTo!, plan.boardAt) > 25;
    final movedUser = _walkPlannedFrom == null || distance.as(LengthUnit.Meter, _walkPlannedFrom!, here) > 25;
    if (!movedSpot && !movedUser) return;
    _walkPlannedTo = plan.boardAt;
    _walkPlannedFrom = here;
    if (_walk == null) setState(() => _walk = WalkingRouteService.straight(here, plan.boardAt));
    _walking.route(here, plan.boardAt).then((walk) {
      if (!mounted || _selectedVehicleId != id) return;
      setState(() => _walk = walk);
    });
    _nameBoardingSpot(plan.boardAt, id);
  }

  /// Names the boarding spot after the nearest stop or landmark ("near …").
  Future<void> _nameBoardingSpot(LatLng spot, String vehicleId) async {
    const distance = Distance();
    String? name;
    var best = 120.0;
    for (final stop in widget.stops) {
      final m = distance.as(LengthUnit.Meter, spot, stop.location);
      if (m < best) { best = m; name = stop.name; }
    }
    if (name == null) {
      final landmarks = await PlaceIndex.landmarks();
      name = landmarks.nearest(spot, maxMetres: 150)?.place.name;
    }
    if (!mounted || _selectedVehicleId != vehicleId) return;
    setState(() => _boardName = name);
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
    final here = await _locate();
    if (here != null) _mapController.move(here, 15);
  }

  /// Asks for permission if needed, takes a fix and starts following the
  /// phone. Returns null (after telling the commuter why) on failure.
  Future<LatLng?> _locate() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showMessage('Location permission was not granted.');
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return null;
      final here = LatLng(position.latitude, position.longitude);
      _setCurrentLocation(here);
      _startFollowing();
      return here;
    } catch (_) {
      _showMessage('Unable to get your current location.');
      return null;
    }
  }

  /// Follows the phone from the start when location was already allowed
  /// (never prompts — the locate button does that).
  Future<void> _followIfAllowed() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        _startFollowing();
      }
    } catch (_) {
      // No location support here; the locate button still reports why.
    }
  }

  void _startFollowing() {
    if (_positionSub != null || !mounted) return;
    final LocationSettings settings = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        // Ask Android for a fix every second; the default can be much slower.
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2,
            intervalDuration: const Duration(seconds: 1),
          )
        : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2);
    _positionSub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) {
        // Indoors Android mixes in Wi-Fi/cell fixes that can be 50-100 m off,
        // which made the dot hop around. Once we have a position, skip any
        // fix the phone itself rates worse than _maxFixErrorM.
        if (_currentLocation != null && p.accuracy > _maxFixErrorM) return;
        _setCurrentLocation(LatLng(p.latitude, p.longitude));
      },
      onError: (_) {
        _positionSub?.cancel();
        _positionSub = null;
      },
    );
  }

  void _setCurrentLocation(LatLng here) {
    if (!mounted) return;
    setState(() => _currentLocation = here);
    if (_selectedVehicleId != null) _updateBoarding();
    // Re-sort "Nearby Vehicles" only after a real move, not on every fix.
    final last = _lastSortedAt;
    if (last == null || const Distance().as(LengthUnit.Meter, last, here) > 25) {
      _lastSortedAt = here;
      _fleetVersion.value++;
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- UI ----------

  void _setMapExpanded(bool expanded) {
    if (expanded == _mapExpanded) return;
    setState(() => _mapExpanded = expanded);
    if (!expanded) return;
    // The sheet starts at its handle and slides up into view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapExpanded && _sheet.isAttached) {
        _sheet.animateTo(_sheetOpen, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  void _toggleSheet(double minSize) {
    if (!_sheet.isAttached) return;
    final open = _sheet.size > minSize + 0.02;
    _sheet.animateTo(
      open ? minSize : _sheetOpen,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back leaves full screen instead of leaving the app.
      canPop: !_mapExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setMapExpanded(false);
      },
      child: _mapExpanded ? _buildFullScreen() : _buildContent(context),
    );
  }

  Widget _liveMap({required bool expanded}) {
    return LiveMap(
      key: _mapKey,
      controller: _mapController,
      stops: widget.stops,
      tracks: _tracks,
      clock: _clock,
      frame: _frame,
      currentLocation: _currentLocation,
      onMapReady: _onMapReady,
      selectedVehicleId: _selectedVehicleId,
      onClearSelection: _clearSelectedVehicle,
      walkPath: _walk?.points,
      boardAt: _plan?.boardAt,
      jeepPath: _plan?.jeepPath,
      expanded: expanded,
      onToggleExpanded: () => _setMapExpanded(!_mapExpanded),
      // Full screen: the buttons sit above the sheet, placed below.
      showControls: !expanded,
      topInset: expanded ? 56 : 0,
    );
  }

  /// "Catch the jeep" card, when a jeep is picked and the walk is known.
  Widget? _boardingCard() {
    if (_selectedVehicleId == null || _plan == null || _walk == null) return null;
    return _BoardingCard(
      routeCode: _routeOf(_selectedVehicleId!)?.code ?? 'PUV',
      plan: _plan!,
      walk: _walk!,
      boardName: _boardName,
      jeepSpeedKmh: _tracks[_selectedVehicleId!]?.latest.speed,
      onHide: _clearSelectedVehicle,
    );
  }

  List<Widget> _nearbySection(BuildContext context) => [
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
            selectedId: _selectedVehicleId,
            onSelected: _pickNearbyVehicle,
          ),
        ),
      ];

  Widget _buildContent(BuildContext context) {
    final boarding = _boardingCard();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SearchField(onTap: _searchDestination),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: 320, child: _liveMap(expanded: false)),
        if (boarding != null) ...[
          const SizedBox(height: AppSpacing.sm),
          boarding,
        ],
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
        ..._nearbySection(context),
      ],
    );
  }

  /// Map edge to edge, search on top, buttons on the right riding above a
  /// draggable "Nearby Vehicles" sheet.
  Widget _buildFullScreen() {
    return LayoutBuilder(
      builder: (context, box) {
        final height = box.maxHeight;
        final minSize = (_sheetHandle / height).clamp(0.02, 0.2);
        final boarding = _boardingCard();
        return Stack(
          children: [
            Positioned.fill(child: _liveMap(expanded: true)),
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              top: AppSpacing.sm,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(6),
                child: _SearchField(onTap: _searchDestination),
              ),
            ),
            ValueListenableBuilder<double>(
              valueListenable: _sheetExtent,
              builder: (context, extent, controls) {
                final bottom = extent.clamp(minSize, 1.0) * height + AppSpacing.xs;
                // Fade the buttons out once the sheet climbs into their way.
                final hidden = bottom > height * 0.55;
                return Positioned(
                  right: AppSpacing.sm,
                  bottom: bottom,
                  child: IgnorePointer(
                    ignoring: hidden,
                    child: AnimatedOpacity(
                      opacity: hidden ? 0 : 1,
                      duration: const Duration(milliseconds: 150),
                      child: controls,
                    ),
                  ),
                );
              },
              child: MapControls(
                controller: _mapController,
                expanded: true,
                onToggleExpanded: () => _setMapExpanded(false),
                onLocate: _centerOnMyLocation,
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                _sheetExtent.value = n.extent;
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: minSize,
                minChildSize: minSize,
                maxChildSize: _sheetMax,
                snap: true,
                snapSizes: const [_sheetOpen],
                builder: (context, scroll) => Material(
                  key: const Key('nearbySheet'),
                  color: Colors.white,
                  elevation: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.sm)),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: scroll,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                    children: [
                      // Drag here, or tap to open / minimize.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleSheet(minSize),
                        child: SizedBox(
                          height: _sheetHandle,
                          child: Center(
                            child: Container(
                              key: const Key('nearbySheetHandle'),
                              width: 64,
                              height: 5,
                              decoration: BoxDecoration(
                                color: AppColors.divider,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (boarding != null) ...[boarding, const SizedBox(height: AppSpacing.sm)],
                      ..._nearbySection(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
              Expanded(
                child: Text(
                  'Search destination...',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 16, color: AppColors.navInactive),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "How to catch it": the walk to the boarding spot and where the jeep is.
class _BoardingCard extends StatelessWidget {
  const _BoardingCard({
    required this.routeCode,
    required this.plan,
    required this.walk,
    required this.boardName,
    required this.jeepSpeedKmh,
    required this.onHide,
  });

  final String routeCode;
  final BoardingPlan plan;
  final WalkingRoute walk;
  final String? boardName;
  final double? jeepSpeedKmh;
  final VoidCallback onHide;

  static String _metres(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final where = boardName == null ? 'the boarding spot' : 'near $boardName';
    final jeep = plan.jeepToBoardM;
    final String jeepLine;
    if (!plan.onRoute) {
      jeepLine = 'This route has no map line yet, so the walk goes to where the PUV is now.';
    } else if (jeep == null) {
      jeepLine = 'This $routeCode has already passed that spot. Wait there for the next one, or pick another vehicle.';
    } else if (jeep < 30) {
      jeepLine = 'The $routeCode is at that spot now.';
    } else {
      jeepLine = 'The $routeCode is ${_metres(jeep)} away along its route — about '
          '${jeepMinutes(jeep, jeepSpeedKmh)} min to reach it.';
    }
    final walkMins = walk.minutes;
    final shortWalk = walk.metres < 15;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        side: const BorderSide(color: AppColors.brandTeal, width: 1.4),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2, right: AppSpacing.sm),
              child: Icon(Icons.directions_walk, color: AppColors.brandTeal, size: 28),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Catch the $routeCode', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    shortWalk
                        ? 'You are already on its route — wait right where you are.'
                        : 'Walk ${_metres(walk.metres)} · ≈ ${walk.steps} steps · $walkMins min to $where.',
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (!walk.byRoad && !shortWalk)
                    const Text('Straight-line estimate (walking directions unavailable).',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(jeepLine, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            IconButton(tooltip: 'Hide', onPressed: onHide, icon: const Icon(Icons.close, size: 20)),
          ],
        ),
      ),
    );
  }
}

/// A live jeep in "Nearby Vehicles"; [metres] is null without our location.
typedef NearbyVehicle = ({TransportRoute route, VehicleLiveUpdate update, double? metres});

class _NearbyList extends StatelessWidget {
  const _NearbyList({
    required this.vehicles,
    required this.etaOf,
    required this.selectedId,
    required this.onSelected,
  });

  final List<NearbyVehicle> vehicles;
  final int? Function(VehicleLiveUpdate) etaOf;
  final String? selectedId;
  final ValueChanged<String> onSelected;

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
            distanceM: v.metres,
            delayed: v.update.dutyStatus == 'delayed',
            selected: v.update.vehicleId == selectedId,
            onTap: () => onSelected(v.update.vehicleId),
          ),
      ],
    );
  }
}
