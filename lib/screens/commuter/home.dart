// Home screen
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
import '../../models/selected_trip.dart';
import '../../models/transport_model.dart';
import '../../models/transport_stop.dart';
import '../../models/vehicle_live_update.dart';
import '../../models/vehicle_track.dart';
import '../../models/vehicles.dart';
import '../../services/boarding_planner.dart';
import '../../services/place_search.dart';
import '../../services/ride_matcher.dart';
import '../../services/trip_eta.dart';
import '../../services/trip_progress.dart';
import '../../services/walking_route_service.dart';
import '../../services/websocket_service.dart';
import '../../widgets/commuter/crowd_chip.dart';
import '../../widgets/commuter/commuter_action_tile.dart';
import '../../widgets/commuter/live_map.dart';
import '../../widgets/commuter/nearby_vehicle_card.dart';
import '../../widgets/commuter/selected_trip_card.dart';
import '../../widgets/commuter/trip_route_layers.dart';
import '../../widgets/map_follower.dart';
import '../../widgets/stop_image.dart';
import '../../widgets/stop_search_sheet.dart';
import 'route_map_screen.dart';

/// Home tab
class HomeTab extends StatefulWidget {
  /// Create home tab
  const HomeTab({
    super.key,
    required this.stops,
    required this.routes,
    required this.vehicles,
    this.onUnknownVehicle,
    this.onRefresh,
    this.selectedTrip,
    this.onCancelTrip,
    this.positions,
    this.socket,
    this.walking,
  });

  final List<TransportStop> stops;
  final List<TransportRoute> routes;

  final List<Vehicle> vehicles;

  final VoidCallback? onUnknownVehicle;

  final VoidCallback? onRefresh;

  final SelectedTrip? selectedTrip;
  final VoidCallback? onCancelTrip;

  final Stream<Position>? positions;
  final WebSocketService? socket;
  final WalkingRouteService? walking;

  /// Create widget state
  @override
  State<HomeTab> createState() => _HomeTabState();
}

/// Home tab state
class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  static const int _maxNearby = 5;

  static const double _maxFixErrorM = 25;

  static const double _setOffM = 30;

  final MapController _mapController = MapController();
  late final MapFollower _follow = MapFollower(_mapController, this);
  bool _mapReady = false;
  LatLng? _currentLocation;

  bool _tripOverview = false;
  LatLng? _overviewFrom;

  StreamSubscription<Position>? _positionSub;
  LatLng? _lastSortedAt;

  final Map<String, VehicleTrack> _tracks = {};

  final Stopwatch _clock = Stopwatch()..start();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;

  final ValueNotifier<int> _fleetVersion = ValueNotifier(0);

  String? _selectedVehicleId;

  BoardingPlan? _plan;
  WalkingRoute? _walk;
  WalkingRoute? _jeepWalk;
  bool _walkingToJeep = false;
  String? _boardName;

  late TripProgress? _progress = _progressFor(widget.selectedTrip);

  late TripRouteLayers? _tripLayers = _layersFor(widget.selectedTrip, _progress);

  /// Progress for
  static TripProgress? _progressFor(SelectedTrip? trip) =>
      trip == null ? null : TripProgress(trip.option, trip.routesById);

  /// Layers for
  static TripRouteLayers? _layersFor(SelectedTrip? trip, TripProgress? progress) =>
      trip == null ? null : TripRouteLayers.of(trip.option, trip.routesById, progress: progress);


  bool _mapExpanded = false;

  final GlobalKey _mapKey = GlobalKey();

  final DraggableScrollableController _sheet = DraggableScrollableController();

  final ValueNotifier<double> _sheetExtent = ValueNotifier(0);

  static const double _sheetOpen = 0.34;
  static const double _sheetMax = 0.75;

  static const double _sheetHandle = 30;

  static const double _searchBarBottom = 60;
  LatLng? _walkPlannedTo;
  LatLng? _walkPlannedFrom;
  LatLng? _jeepWalkTo;
  DateTime _lastPlanAt = DateTime.fromMillisecondsSinceEpoch(0);
  late final WalkingRouteService _walking = widget.walking ?? WalkingRouteService();

  late final WebSocketService _socket;

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _socket = (widget.socket ?? WebSocketService())
      ..connect()
      ..listenForMessages(_onVehicleMessage);
    _locateOnOpen();
  }

  /// React to widget update
  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.selectedTrip, widget.selectedTrip)) {
      _arrivedClear?.cancel();
      _boardedNoticeLeg = null;
      _progress = _progressFor(widget.selectedTrip);
      if (_currentLocation case final here?) _progress?.update(here, at: DateTime.now());
      _tripLayers = _layersFor(widget.selectedTrip, _progress);
      _showTrip();
    }
    if (oldWidget.stops.isEmpty && widget.stops.isNotEmpty) _fitToStops();
    if (!identical(oldWidget.vehicles, widget.vehicles) || !identical(oldWidget.routes, widget.routes)) {
      _fleetVersion.value++;
    }
  }

  /// Clean up resources
  @override
  void dispose() {
    _arrivedClear?.cancel();
    _positionSub?.cancel();
    _socket.disconnect();
    _follow.dispose();
    _ticker.dispose();
    _frame.dispose();
    _fleetVersion.dispose();
    _sheet.dispose();
    _sheetExtent.dispose();
    super.dispose();
  }


  /// On vehicle message
  void _onVehicleMessage(dynamic message) {
    if (!mounted) return;

    final update = VehicleLiveUpdate.fromJson(
      jsonDecode(message as String) as Map<String, dynamic>,
    );
    final now = _clock.elapsed;
    final track = _tracks[update.vehicleId];
    if (update.shiftEnded) {
      if (_tracks.remove(update.vehicleId) != null) {
        if (update.vehicleId == _selectedVehicleId) _clearSelectedVehicle();
        _frame.value++;
        _fleetVersion.value++;
      }
      return;
    }
    if (track == null) {
      _tracks[update.vehicleId] = VehicleTrack(update, now);
    } else {
      track.push(update, now);
    }
    if (update.isOffRoute && update.vehicleId == _selectedVehicleId) _clearSelectedVehicle();

    _frame.value++;
    _fleetVersion.value++;
    if (!_ticker.isActive) _ticker.start();
    if (update.location != null && _routeOf(update.vehicleId) == null) widget.onUnknownVehicle?.call();
    if (update.vehicleId == _selectedVehicleId &&
        DateTime.now().difference(_lastPlanAt) > const Duration(seconds: 3)) {
      _updateBoarding();
    }
    if (update.vehicleId == _selectedVehicleId) _followCamera();
  }

  /// On tick
  void _onTick(Duration _) {
    _frame.value++;
    if (!_tracks.values.any((t) => t.isAnimating(_clock.elapsed))) _ticker.stop();
  }

  /// Refresh vehicles
  void _refreshVehicles() {
    _tracks.clear();
    _frame.value++;
    _fleetVersion.value++;
    _socket.connect();
    widget.onRefresh?.call();
  }

  /// Nearby vehicles
  List<NearbyVehicle> _nearbyVehicles({int limit = _maxNearby}) {
    final routesById = {for (final r in widget.routes) r.id: r};
    final routeByVehicle = {
      for (final v in widget.vehicles) v.id: routesById[v.routeId],
    };

    final here = _currentLocation;
    const distance = Distance(roundResult: false);
    final live = [
      for (final track in _tracks.values)
        if (!track.latest.isSignalLost && !track.latest.isUnavailable && !track.latest.isOffRoute &&
            track.latest.location != null)
          if (routeByVehicle[track.latest.vehicleId] case final route?)
            (
              route: route,
              track: track,
              metres: here == null ? null : distance.as(LengthUnit.Meter, here, track.latest.location!),
            ),
    ];

    if (here == null) {
      int eta(VehicleTrack t) => _etaMinutes(t.latest) ?? 1 << 30;
      live.sort((a, b) => eta(a.track).compareTo(eta(b.track)));
      return [
        for (final v in live.take(limit)) (route: v.route, update: v.track.latest, metres: null, plan: null),
      ];
    }

    live.sort((a, b) => a.metres!.compareTo(b.metres!));
    final nearest = <NearbyVehicle>[
      for (final v in live.take(limit))
        (
          route: v.route,
          update: v.track.latest,
          metres: v.metres,
          plan: _planFor(v.route, v.track.latest.location!, here, v.track.headingAt(_clock.elapsed)),
        ),
    ];
    bool passed(NearbyVehicle v) => v.plan?.jeepPassed ?? false;
    return [...nearest.where((v) => !passed(v)), ...nearest.where(passed)];
  }

  /// Plan for
  static BoardingPlan _planFor(TransportRoute? route, LatLng jeep, LatLng here, double? heading) => planBoarding(
        route: lineAsDriven(route?.geometry ?? const [], jeep: jeep, user: here, heading: heading),
        user: here,
        jeep: jeep,
        stops: route?.stops ?? const [],
      );


  /// Pick nearby vehicle
  Future<void> _pickNearbyVehicle(String vehicleId) async {
    if (_selectedVehicleId != vehicleId && _currentLocation == null && await _locate() == null) return;
    if (mounted) _selectVehicle(vehicleId);
  }

  /// Select vehicle
  void _selectVehicle(String vehicleId) {
    if (_selectedVehicleId == vehicleId) return _clearSelectedVehicle();
    setState(() {
      _selectedVehicleId = vehicleId;
      _resetBoarding();
    });
    final from = _tracks[vehicleId]?.positionAt(_clock.elapsed);
    final to = _currentLocation;
    if (!_mapReady || from == null) return;
    if (to == null) {
      _showMessage('Turn on location to see how to reach this vehicle.');
      _follow.stop();
      _mapController.move(from, 16);
      return;
    }
    _updateBoarding();
    _tripOverview = false;
    _follow.resume();
    _followCamera();
  }

  /// Clear selected vehicle
  void _clearSelectedVehicle() {
    setState(() {
      _selectedVehicleId = null;
      _resetBoarding();
    });
    if (!_follow.following.value) return;
    _follow.resume();
    _followCamera();
  }

  /// Reset boarding
  void _resetBoarding() {
    _plan = null;
    _walk = null;
    _jeepWalk = null;
    _walkingToJeep = false;
    _boardName = null;
    _walkPlannedTo = null;
    _jeepWalkTo = null;
  }

  /// Route of
  TransportRoute? _routeOf(String vehicleId) {
    for (final v in widget.vehicles) {
      if (v.id != vehicleId) continue;
      for (final r in widget.routes) {
        if (r.id == v.routeId) return r;
      }
    }
    return null;
  }

  /// Update boarding
  void _updateBoarding() {
    final id = _selectedVehicleId;
    final here = _currentLocation;
    final jeep = id == null ? null : _tracks[id]?.positionAt(_clock.elapsed);
    if (id == null || here == null || jeep == null) return;
    _lastPlanAt = DateTime.now();
    final plan = _planFor(_routeOf(id), jeep, here, _tracks[id]?.headingAt(_clock.elapsed));
    setState(() => _plan = plan);

    const distance = Distance();
    final movedSpot = _walkPlannedTo == null || distance.as(LengthUnit.Meter, _walkPlannedTo!, plan.boardAt) > 25;
    final movedUser = _walkPlannedFrom == null || distance.as(LengthUnit.Meter, _walkPlannedFrom!, here) > 25;
    final movedJeep = _jeepWalkTo == null || distance.as(LengthUnit.Meter, _jeepWalkTo!, jeep) > 100;
    if (movedUser || movedJeep) _planWalkToJeep(id, here, jeep);
    if (!movedSpot && !movedUser) return;
    _walkPlannedTo = plan.boardAt;
    _walkPlannedFrom = here;
    if (_walk == null) setState(() => _walk = WalkingRouteService.straight(here, plan.boardAt));
    _walking.route(here, plan.boardAt).then((walk) {
      if (!mounted || _selectedVehicleId != id) return;
      setState(() => _walk = walk);
    });
    _nameBoardingSpot(plan, id);
  }

  /// Plan walk to jeep
  void _planWalkToJeep(String id, LatLng here, LatLng jeep) {
    _jeepWalkTo = jeep;
    if (_jeepWalk == null) setState(() => _jeepWalk = WalkingRouteService.straight(here, jeep));
    _walking.route(here, jeep).then((walk) {
      if (!mounted || _selectedVehicleId != id) return;
      setState(() => _jeepWalk = walk);
    });
  }

  /// Name boarding spot
  Future<void> _nameBoardingSpot(BoardingPlan plan, String vehicleId) async {
    if (plan.stopName != null) {
      setState(() => _boardName = plan.stopName);
      return;
    }
    final spot = plan.boardAt;
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

  /// ETA minutes
  int? _etaMinutes(VehicleLiveUpdate update) {
    final eta = update.etaNextStop;
    return eta != null && eta >= 0 ? eta : null;
  }


  /// On map ready
  void _onMapReady() {
    _mapReady = true;
    _follow.mapReady();
    if (_tripLayers != null) {
      _showTrip();
    } else if (_currentLocation != null) {
      _followCamera();
    } else {
      _fitToStops();
    }
  }

  /// Show trip
  void _showTrip() {
    final fit = _tripLayers?.cameraFit;
    _tripOverview = fit != null;
    _overviewFrom = _currentLocation;
    _follow.resume();
    if (fit == null) {
      _followCamera();
    } else if (_mapReady) {
      _mapController.fitCamera(fit);
    }
  }

  /// Follow camera
  void _followCamera() {
    if (!_follow.following.value) return;
    final here = _currentLocation;
    if (here == null) return;
    final id = _selectedVehicleId;
    final jeep = id == null || id == _ridingVehicleId ? null : _tracks[id]?.latest.location;
    if (jeep != null) {
      _follow.frame([here, jeep, if (_plan case final plan?) plan.boardAt], covered: _mapCovered);
    } else if (!_onTripOverview(here)) {
      _follow.center(here);
    }
  }

  EdgeInsets get _mapCovered {
    if (!_mapExpanded) return EdgeInsets.zero;
    final sheet = _sheetExtent.value.clamp(0.0, _sheetOpen);
    return EdgeInsets.only(top: _searchBarBottom, bottom: sheet * _mapController.camera.size.height);
  }

  /// On trip overview
  bool _onTripOverview(LatLng here) {
    if (!_tripOverview) return false;
    final from = _overviewFrom ??= here;
    _tripOverview = const Distance().as(LengthUnit.Meter, from, here) < _setOffM;
    return _tripOverview;
  }

  /// Open selected trip
  void _openSelectedTrip() {
    final trip = widget.selectedTrip;
    if (trip == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RouteMapScreen(option: trip.option, routesById: trip.routesById),
    ));
  }

  /// Selected trip slot
  Widget _selectedTripSlot({required EdgeInsets padding}) {
    final trip = widget.selectedTrip;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: trip == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: padding,
              child: ValueListenableBuilder<int>(
                valueListenable: _fleetVersion,
                builder: (context, _, __) => SelectedTripCard(
                  trip: trip,
                  progress: _progress?.state,
                  eta: _tripEta(trip),
                  boardedPlate: _boardedVehicle()?.plateNumber,
                  onOpen: _openSelectedTrip,
                  onCancel: widget.onCancelTrip ?? () {},
                ),
              ),
            ),
    );
  }

  /// Live jeeps
  List<LiveJeep> _liveJeeps() {
    final now = _clock.elapsed;
    final routeOf = {for (final v in widget.vehicles) v.id: v.routeId};
    return [
      for (final MapEntry(key: id, value: track) in _tracks.entries)
        if (!track.latest.isSignalLost && !track.latest.isUnavailable && !track.latest.isOffRoute)
          if (routeOf[id] case final routeId?)
            if (track.positionAt(now) ?? track.latest.location case final at?)
              (id: id, routeId: routeId, at: at, heading: track.headingAt(now) ?? track.latest.heading),
    ];
  }

  /// Trip ETA
  TripEta? _tripEta(SelectedTrip trip) {
    final state = _progress?.state;
    final here = _currentLocation;
    if (state == null || here == null) return null;
    return tripEta(
      option: trip.option,
      progress: state,
      here: here,
      now: DateTime.now(),
      routesById: {for (final r in widget.routes) r.id: r, ...trip.routesById},
      jeeps: _liveJeeps(),
    );
  }

  /// Boarded vehicle
  Vehicle? _boardedVehicle() {
    final id = _ridingVehicleId;
    final progress = _progress;
    final state = progress?.state;
    final trip = widget.selectedTrip;
    if (id == null || progress == null || state == null || trip == null || state.phase == TripPhase.arrived) {
      return null;
    }
    final leg = trip.option.legs[state.legIndex];
    Vehicle? vehicle;
    for (final v in widget.vehicles) {
      if (v.id == id) vehicle = v;
    }
    if (vehicle == null || vehicle.routeId != leg.routeId) return null;
    final track = _tracks[id];
    final heading = track?.headingAt(_clock.elapsed) ?? track?.latest.heading;
    final at = track?.latest.location;
    final line = progress.lineOf(state.legIndex);
    if (heading != null && at != null && line.length >= 2) {
      final pos = projectOnLine(line, at);
      if (pos != null && headingAgainstLine(line, pos, heading)) return null;
    }
    return vehicle;
  }

  /// Fit to stops
  void _fitToStops() {
    final stops = widget.stops;
    if (!_mapReady || stops.isEmpty || _tripLayers != null || _currentLocation != null) return;
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

  /// Search destination
  Future<void> _searchDestination() async {
    if (widget.stops.isEmpty) {
      _showMessage('Stops are still loading. Please try again in a moment.');
      return;
    }
    final stop = await showStopSearchSheet(context, widget.stops);
    if (stop == null || !mounted) return;
    _follow.stop();
    _mapController.move(stop.location, 16);
    showStopDetailsSheet(context, stop);
  }

  /// Center on my location
  Future<void> _centerOnMyLocation() async {
    _tripOverview = false;
    _follow.resume();
    if (_currentLocation != null && _positionSub != null) return _followCamera();
    await _locate();
  }

  /// Locate home tab
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
      _startPositionUpdates();
      return here;
    } catch (_) {
      _showMessage('Unable to get your current location.');
      return null;
    }
  }

  /// Locate on open
  Future<void> _locateOnOpen() async {
    if (widget.positions != null) return _startPositionUpdates();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        _startPositionUpdates();
      }
    } catch (_) {
    }
  }

  /// Start position updates
  void _startPositionUpdates() {
    if (_positionSub != null || !mounted) return;
    final LocationSettings settings = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? AndroidSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 2,
            intervalDuration: const Duration(seconds: 1),
          )
        : const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 2);
    _positionSub = (widget.positions ?? Geolocator.getPositionStream(locationSettings: settings)).listen(
      (p) {
        if (_currentLocation != null && p.accuracy > _maxFixErrorM) return;
        _setCurrentLocation(LatLng(p.latitude, p.longitude), speedMps: p.speed);
      },
      onError: (_) {
        _positionSub?.cancel();
        _positionSub = null;
      },
    );
  }

  /// Set current location
  void _setCurrentLocation(LatLng here, {double? speedMps}) {
    if (!mounted) return;
    final now = _clock.elapsed;
    final jeeps = {
      for (final e in _tracks.entries)
        if (!e.value.latest.isSignalLost)
          if (e.value.positionAt(now) case final p?) e.key: p,
    };
    setState(() {
      _currentLocation = here;
      _ridingVehicleId = _ride.update(here, DateTime.now(), jeeps, reportedSpeedMps: speedMps);
      _trackTrip(here, speedMps);
    });
    if (_selectedVehicleId != null) _updateBoarding();
    _followCamera();
    final last = _lastSortedAt;
    if (last == null || const Distance().as(LengthUnit.Meter, last, here) > 25) {
      _lastSortedAt = here;
      _fleetVersion.value++;
    }
  }

  /// Trip vehicle IDs
  Set<String>? _tripVehicleIds() {
    final trip = widget.selectedTrip;
    if (trip == null) return null;
    final routeIds = {for (final leg in trip.option.legs) leg.routeId};
    return {
      for (final v in widget.vehicles)
        if (routeIds.contains(v.routeId)) v.id,
      if (_selectedVehicleId case final id?) id,
    };
  }

  /// Track trip
  void _trackTrip(LatLng here, double? speedMps) {
    final progress = _progress;
    final trip = widget.selectedTrip;
    if (progress == null || trip == null) return;
    final before = progress.state;
    var now = progress.update(here, at: DateTime.now(), reportedSpeedMps: speedMps);
    final boarded = _boardedVehicle();
    if (boarded != null && !now.isRiding) now = progress.boarded(here, at: DateTime.now());
    _tripLayers = _layersFor(trip, progress);
    final leg = trip.option.legs[now.legIndex];
    final name = leg.routeCode ?? leg.routeName;

    String? boardedMessage;
    if (boarded != null && now.phase == TripPhase.riding && _boardedNoticeLeg != now.legIndex) {
      _boardedNoticeLeg = now.legIndex;
      final plate = boarded.plateNumber.isEmpty ? '' : ' (${boarded.plateNumber})';
      boardedMessage = "You're on the $name you were waiting for$plate. We'll tell you when to get off.";
    }
    if (before?.phase == now.phase && before?.legIndex == now.legIndex) {
      if (boardedMessage != null) _postMessage(boardedMessage, replace: true);
      return;
    }
    final message = switch (now.phase) {
      TripPhase.riding when before?.isRiding != true => boardedMessage ?? "You're on the $name. We'll tell you when to get off.",
      TripPhase.alightSoon => 'Get off soon at ${leg.alightLabel}.',
      TripPhase.arrived => "You've arrived at ${trip.option.legs.last.alightLabel}.",
      TripPhase.toBoard when (before?.legIndex ?? 0) < now.legIndex => 'Transfer: walk to ${leg.boardLabel} for the $name.',
      _ => boardedMessage,
    };
    if (message != null) _postMessage(message, replace: message == boardedMessage);
    if (now.phase == TripPhase.arrived) {
      _arrivedClear?.cancel();
      _arrivedClear = Timer(clearAfterArrival, () {
        if (mounted && identical(widget.selectedTrip, trip)) widget.onCancelTrip?.call();
      });
    }
  }

  final RideMatcher _ride = RideMatcher();
  String? _ridingVehicleId;

  int? _boardedNoticeLeg;

  static const Duration clearAfterArrival = Duration(seconds: 15);
  Timer? _arrivedClear;

  /// Show message
  void _showMessage(String text, {bool replace = false}) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (replace) messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  /// Post message
  void _postMessage(String text, {bool replace = false}) =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _showMessage(text, replace: replace));


  /// Set map expanded
  void _setMapExpanded(bool expanded) {
    if (expanded == _mapExpanded) return;
    setState(() => _mapExpanded = expanded);
    if (!expanded) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapExpanded && _sheet.isAttached) {
        _sheet.animateTo(_sheetOpen, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      }
    });
  }

  /// Toggle sheet
  void _toggleSheet(double minSize) {
    if (!_sheet.isAttached) return;
    final open = _sheet.size > minSize + 0.02;
    _sheet.animateTo(
      open ? minSize : _sheetOpen,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_mapExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setMapExpanded(false);
      },
      child: _mapExpanded ? _buildFullScreen() : _buildContent(context),
    );
  }

  /// Live map
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
      onMapEvent: _follow.onMapEvent,
      onLocate: _centerOnMyLocation,
      following: _follow.following,
      selectedVehicleId: _selectedVehicleId,
      onClearSelection: _clearSelectedVehicle,
      walkPath: (_walkingToJeep ? _jeepWalk : _walk)?.points,
      boardAt: _plan?.boardAt,
      jeepPath: _plan?.jeepPath,
      expanded: expanded,
      onToggleExpanded: () => _setMapExpanded(!_mapExpanded),
      showControls: !expanded,
      topInset: expanded ? 56 : 0,
      trip: _tripLayers,
      onlyVehicles: _tripVehicleIds(),
      ridingVehicleId: _ridingVehicleId,
    );
  }

  /// Boarding card
  Widget? _boardingCard() {
    if (_selectedVehicleId == null || _plan == null || _walk == null) return null;
    return _BoardingCard(
      routeCode: _routeOf(_selectedVehicleId!)?.code ?? 'PUV',
      plan: _plan!,
      walk: _walk!,
      jeepWalk: _jeepWalk,
      walkingToJeep: _walkingToJeep,
      onWalkTo: (toJeep) => setState(() => _walkingToJeep = toJeep),
      boardName: _boardName,
      jeepSpeedKmh: _tracks[_selectedVehicleId!]?.latest.speed,
      crowd: _tracks[_selectedVehicleId!]?.latest.crowd,
      onHide: _clearSelectedVehicle,
    );
  }

  /// Nearby section
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
            notInService: _tracks.values
                .where((t) => !t.latest.isSignalLost && t.latest.isUnavailable && t.latest.location != null)
                .length,
            etaOf: _etaMinutes,
            selectedId: _selectedVehicleId,
            onSelected: _pickNearbyVehicle,
          ),
        ),
      ];

  /// Build content
  Widget _buildContent(BuildContext context) {
    final boarding = _boardingCard();
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        _SearchField(onTap: _searchDestination),
        _selectedTripSlot(padding: const EdgeInsets.only(top: AppSpacing.sm)),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: 320, child: _liveMap(expanded: false)),
        if (boarding != null) ...[
          const SizedBox(height: AppSpacing.sm),
          boarding,
        ],
        const SizedBox(height: AppSpacing.md),
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

  /// Build full screen
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
                following: _follow.following,
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
                      _selectedTripSlot(padding: const EdgeInsets.only(bottom: AppSpacing.sm)),
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

/// Search field
class _SearchField extends StatelessWidget {
  /// Create search field
  const _SearchField({required this.onTap});

  final VoidCallback onTap;

  /// Build the widget
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

/// Boarding card
class _BoardingCard extends StatelessWidget {
  /// Create boarding card
  const _BoardingCard({
    required this.routeCode,
    required this.plan,
    required this.walk,
    required this.jeepWalk,
    required this.walkingToJeep,
    required this.onWalkTo,
    required this.boardName,
    required this.jeepSpeedKmh,
    required this.onHide,
    this.crowd,
  });

  final String routeCode;
  final String? crowd;
  final BoardingPlan plan;
  final WalkingRoute walk;
  final WalkingRoute? jeepWalk;
  final bool walkingToJeep;
  final ValueChanged<bool> onWalkTo;
  final String? boardName;
  final double? jeepSpeedKmh;
  final VoidCallback onHide;

  String get _jeepLine {
    final jeep = plan.jeepToBoardM;
    if (!plan.onRoute) return 'This route has no map line yet, so the walk goes to where the PUV is now.';
    if (jeep == null) {
      return 'This $routeCode has already passed that spot. Wait there for the next one, or pick another vehicle.';
    }
    if (jeep < 30) return 'The $routeCode is at that spot now.';
    final jeepMin = jeepMinutes(jeep, jeepSpeedKmh);
    final late = walk.minutes - jeepMin;
    final race = late <= 0
        ? "You'd get there first."
        : 'It gets there about $late min before you: hurry, or wait for the next one.';
    return 'The $routeCode is ${formatKm(jeep)} from that spot along its route, about $jeepMin min. $race';
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final where = plan.stopName != null || boardName != null
        ? (plan.stopName ?? 'near $boardName')
        : 'the boarding spot';
    final shortWalk = walk.metres < 15;
    final toJeep = jeepWalk;
    final shown = walkingToJeep && toJeep != null ? toJeep : walk;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Catch the $routeCode', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      Text(
                        'The PUV is ${formatKm(plan.jeepStraightM)} from you',
                        key: const Key('jeepDistance'),
                        style: const TextStyle(fontSize: 14, color: AppColors.brandTeal, fontWeight: FontWeight.w500),
                      ),
                      if (CrowdChip.labelFor(crowd) != null)
                        Padding(padding: const EdgeInsets.only(top: 4), child: CrowdChip(level: crowd)),
                    ],
                  ),
                ),
                IconButton(tooltip: 'Hide', onPressed: onHide, icon: const Icon(Icons.close, size: 20)),
              ],
            ),
            const SizedBox(height: 4),
            if (shortWalk)
              const Text('You are already on its route: wait right where you are.', style: TextStyle(fontSize: 14))
            else if (plan.onRoute)
              _WalkOption(
                key: const Key('walkToStop'),
                icon: Icons.directions_walk,
                title: 'Walk to $where',
                walk: walk,
                selected: !walkingToJeep,
                onTap: () => onWalkTo(false),
              ),
            if (toJeep != null)
              _WalkOption(
                key: const Key('walkToJeep'),
                icon: Icons.directions_bus,
                title: 'Walk to the PUV',
                walk: toJeep,
                selected: walkingToJeep || !plan.onRoute,
                onTap: () => onWalkTo(true),
              ),
            if (!shown.byRoad && !shortWalk)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Text('Straight-line estimate (walking directions unavailable).',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: Text(_jeepLine, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Walk option widget
class _WalkOption extends StatelessWidget {
  /// Create walk option
  const _WalkOption({
    super.key,
    required this.icon,
    required this.title,
    required this.walk,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final WalkingRoute walk;
  final bool selected;
  final VoidCallback onTap;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, right: AppSpacing.xs),
      child: Material(
        color: selected ? AppColors.headerSky : Colors.transparent,
        borderRadius: BorderRadius.circular(AppSpacing.xs),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.xs),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.brandTeal),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      Text(
                        '${formatKm(walk.metres)} · ≈ ${walk.steps} steps',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${walk.minutes} min',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.brandTeal),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

typedef NearbyVehicle = ({TransportRoute route, VehicleLiveUpdate update, double? metres, BoardingPlan? plan});

/// Nearby list
class _NearbyList extends StatelessWidget {
  /// Reach minutes
  static int? _reachMinutes(NearbyVehicle v) {
    final metres = v.plan?.jeepToBoardM;
    return metres == null ? null : jeepMinutes(metres, v.update.speed);
  }

  /// Create nearby list
  const _NearbyList({
    required this.vehicles,
    this.notInService = 0,
    required this.etaOf,
    required this.selectedId,
    required this.onSelected,
  });

  final List<NearbyVehicle> vehicles;

  final int notInService;
  final int? Function(VehicleLiveUpdate) etaOf;
  final String? selectedId;
  final ValueChanged<String> onSelected;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      final n = notInService;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Text(
          n == 0
              ? 'No vehicles nearby right now.'
              : 'No vehicles in service nearby right now. ${n == 1 ? '1 PUV' : '$n PUVs'} on the map '
                  "${n == 1 ? "isn't" : "aren't"} taking passengers (shown greyed out).",
          key: const Key('nearbyEmpty'),
        ),
      );
    }
    return Column(
      children: [
        for (final v in vehicles)
          NearbyVehicleCard(
            routeCode: v.route.code,
            routeName: v.route.name,
            etaMinutes: _reachMinutes(v) ?? etaOf(v.update),
            etaCaption: _reachMinutes(v) != null ? 'to reach you' : 'to next stop',
            passed: v.plan?.jeepPassed ?? false,
            distanceM: v.metres,
            delayed: v.update.dutyStatus == 'delayed',
            selected: v.update.vehicleId == selectedId,
            crowd: v.update.crowd,
            onTap: () => onSelected(v.update.vehicleId),
          ),
      ],
    );
  }
}
