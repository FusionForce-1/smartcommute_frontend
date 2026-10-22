// lib/screens/commuter/route_map_screen.dart
//
// "View Selected Route on Map": draws each leg's route line with its
// board / alight stops (widgets/commuter/trip_route_layers.dart), framed to
// fit, above the fare breakdown. With [onSelect], a "Select this route"
// button below sends the route to the Home map until it's cancelled.
//
// It also follows the jeeps live on those routes (WSS /ws/live): each one
// is a marker on the map and a card under it. Picking a jeep shows how far
// it still is from the commuter's boarding stop, along its route, or that
// it has already passed it (services/boarding_planner.dart).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';
import '../../config/theme_config.dart';
import '../../models/models.dart' show StopModel;
import '../../models/transport_model.dart';
import '../../models/trip_plan.dart';
import '../../models/vehicle_live_update.dart';
import '../../models/vehicle_track.dart';
import '../../models/vehicles.dart';
import '../../services/boarding_planner.dart';
import '../../services/websocket_service.dart';
import '../../widgets/commuter/commuter_page_header.dart';
import '../../widgets/commuter/trip_route_layers.dart';
import '../../widgets/commuter/vehicle_marker.dart';
import '../../widgets/fare_breakdown_sheet.dart';

/// Loads the fleet list (GET /vehicles): which route each jeep runs on.
typedef VehiclesLoader = Future<List<Vehicle>> Function();

class RouteMapScreen extends StatefulWidget {
  const RouteMapScreen({
    super.key,
    required this.option,
    required this.routesById,
    this.loadVehicles,
    this.socket,
    this.onSelect,
  });

  final RouteOption option;
  final Map<String, TransportRoute> routesById;

  /// Without it, no live jeeps are shown (just the route).
  final VehiclesLoader? loadVehicles;

  /// For tests; defaults to a live connection to /ws/live.
  final WebSocketService? socket;

  /// "Select this route"; null hides the button (e.g. opened from Home,
  /// where this route is already the selected one).
  final VoidCallback? onSelect;

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

/// A live jeep on one of the option's legs, and how it relates to that
/// leg's boarding stop.
typedef RouteJeep = ({
  String vehicleId,
  String plate,
  RouteLeg leg,
  int legIndex,
  VehicleTrack track,
  BoardingPlan? plan,
});

class _RouteMapScreenState extends State<RouteMapScreen> with SingleTickerProviderStateMixin {
  final MapController _map = MapController();
  bool _mapReady = false;

  // Jeep id -> route id / plate, from /vehicles.
  Map<String, Vehicle> _fleet = const {};
  bool _fleetLoaded = false;
  DateTime _lastFleetLoad = DateTime.fromMillisecondsSinceEpoch(0);

  final Map<String, VehicleTrack> _tracks = {};
  final Stopwatch _clock = Stopwatch()..start();
  final ValueNotifier<int> _frame = ValueNotifier(0);
  late final Ticker _ticker;
  WebSocketService? _socket;

  String? _selectedId;

  RouteOption get _option => widget.option;
  Set<String> get _legRouteIds => {for (final leg in _option.legs) leg.routeId};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      _frame.value++;
      if (!_tracks.values.any((t) => t.isAnimating(_clock.elapsed))) _ticker.stop();
    });
    // Without the fleet list a jeep can't be placed on a route: no socket.
    if (widget.loadVehicles == null) return;
    _loadFleet();
    _socket = (widget.socket ?? WebSocketService())
      ..connect()
      ..listenForMessages(_onMessage);
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Future<void> _loadFleet() async {
    final load = widget.loadVehicles;
    if (load == null) return;
    _lastFleetLoad = DateTime.now();
    try {
      final list = await load();
      if (!mounted) return;
      setState(() {
        _fleet = {for (final v in list) v.id: v};
        _fleetLoaded = true;
      });
    } catch (e) {
      debugPrint('Route map: failed to load vehicles: $e');
      if (mounted) setState(() => _fleetLoaded = true);
    }
  }

  void _onMessage(dynamic message) {
    if (!mounted) return;
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(message as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (json['vehicle_id'] is! String) return; // e.g. transit alerts
    final update = VehicleLiveUpdate.fromJson(json);

    final vehicle = _fleet[update.vehicleId];
    if (vehicle == null) {
      // Added after we loaded the list: look again (at most every 30 s).
      if (DateTime.now().difference(_lastFleetLoad) > const Duration(seconds: 30)) _loadFleet();
      return;
    }
    if (!_legRouteIds.contains(vehicle.routeId)) return; // a jeep on another route

    if (update.shiftEnded) {
      if (_tracks.remove(update.vehicleId) != null) {
        if (update.vehicleId == _selectedId) _selectedId = null;
        _frame.value++;
        setState(() {});
      }
      return;
    }

    final now = _clock.elapsed;
    final track = _tracks[update.vehicleId];
    final isNew = track == null;
    if (isNew) {
      _tracks[update.vehicleId] = VehicleTrack(update, now);
    } else {
      track.push(update, now);
    }
    _frame.value++;
    if (!_ticker.isActive) _ticker.start();
    // The cards (distance, status) follow the latest fix.
    setState(() {});
  }

  /// Live jeeps on the option's routes, those still coming to the boarding
  /// stop first (nearest first), then those that passed it.
  List<RouteJeep> _jeeps() {
    final list = <RouteJeep>[];
    for (final entry in _tracks.entries) {
      final vehicle = _fleet[entry.key];
      if (vehicle == null) continue;
      final legIndex = _option.legs.indexWhere((l) => l.routeId == vehicle.routeId);
      if (legIndex < 0) continue;
      final leg = _option.legs[legIndex];
      final at = entry.value.latest.location;
      final line = widget.routesById[leg.routeId]?.geometry ?? const <LatLng>[];
      final plan = at == null || leg.boardStop.isPlaceholder
          ? null
          : planBoarding(route: line, user: _point(leg.boardStop), jeep: at);
      list.add((
        vehicleId: entry.key,
        plate: vehicle.plateNumber,
        leg: leg,
        legIndex: legIndex,
        track: entry.value,
        plan: plan,
      ));
    }
    double rank(RouteJeep j) {
      if (j.track.latest.isSignalLost || j.track.latest.isUnavailable) return 1e12;
      final m = j.plan?.jeepToBoardM;
      if (m != null) return m;
      return j.plan?.onRoute == false ? j.plan!.walkStraightM : 1e9; // passed it
    }
    list.sort((a, b) => a.legIndex != b.legIndex ? a.legIndex - b.legIndex : rank(a).compareTo(rank(b)));
    return list;
  }

  void _select(RouteJeep jeep) {
    if (_selectedId == jeep.vehicleId) {
      setState(() => _selectedId = null);
      return;
    }
    setState(() => _selectedId = jeep.vehicleId);
    final at = jeep.track.positionAt(_clock.elapsed) ?? jeep.track.latest.location;
    if (!_mapReady || at == null) return;
    final board = jeep.leg.boardStop.isPlaceholder ? null : _point(jeep.leg.boardStop);
    if (board == null) {
      _map.move(at, 16);
    } else {
      _map.fitCamera(CameraFit.coordinates(
        coordinates: [at, board],
        padding: const EdgeInsets.all(56),
        maxZoom: 17,
      ));
    }
  }

  static LatLng _point(StopModel stop) => LatLng(stop.location.lat, stop.location.lng);

  @override
  Widget build(BuildContext context) {
    final layers = TripRouteLayers.of(_option, widget.routesById);
    final polylines = [...layers.lines];
    final markers = layers.markers;

    final jeeps = _jeeps();
    RouteJeep? selected;
    for (final j in jeeps) {
      if (j.vehicleId == _selectedId) selected = j;
    }
    // The selected jeep's way to the boarding stop, dashed.
    final approach = selected?.plan?.jeepPath ?? const <LatLng>[];
    if (approach.length > 1) {
      polylines.add(Polyline(
        points: approach,
        color: AppColors.error,
        strokeWidth: 4,
        pattern: StrokePattern.dashed(segments: const [10, 8]),
      ));
    }

    final framePoints = [
      for (final line in polylines) ...line.points,
      for (final marker in markers) marker.point,
    ];

    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: Column(
        children: [
          const CommuterPageHeader(title: 'Selected Route'),
          Expanded(
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: framePoints.isEmpty ? MapConfig.defaultCenter : framePoints.first,
                initialZoom: 14,
                initialCameraFit: framePoints.length > 1
                    ? CameraFit.coordinates(
                        coordinates: framePoints,
                        padding: const EdgeInsets.all(40),
                        maxZoom: 16,
                      )
                    : null,
                minZoom: MapConfig.minZoom,
                maxZoom: MapConfig.maxZoom,
                cameraConstraint: CameraConstraint.contain(bounds: MapConfig.mapBounds),
                onMapReady: () => _mapReady = true,
              ),
              children: [
                TileLayer(
                  urlTemplate: MapConfig.tileUrl,
                  userAgentPackageName: MapConfig.userAgentPackageName,
                ),
                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: markers),
                // Only this layer repaints per animation frame.
                ValueListenableBuilder<int>(
                  valueListenable: _frame,
                  builder: (context, _, __) {
                    final now = _clock.elapsed;
                    return MarkerLayer(
                      markers: [
                        for (final j in jeeps)
                          if (j.track.positionAt(now) case final point?)
                            Marker(
                              point: point,
                              width: j.vehicleId == _selectedId ? 60 : 50,
                              height: j.vehicleId == _selectedId ? 60 : 50,
                              child: GestureDetector(
                                onTap: () => _select(j),
                                child: VehicleMarker(vehicle: j.track.latest, heading: j.track.headingAt(now)),
                              ),
                            ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          _LiveJeepsPanel(
            jeeps: jeeps,
            selectedId: _selectedId,
            waiting: widget.loadVehicles != null && !_fleetLoaded,
            liveEnabled: widget.loadVehicles != null,
            showRouteCode: _option.legs.length > 1,
            onSelected: _select,
          ),
          _FarePanel(option: _option, onSelect: widget.onSelect),
        ],
      ),
    );
  }
}

/// "PUVs on this route": one card per live PUV; tap to follow it.
class _LiveJeepsPanel extends StatelessWidget {
  const _LiveJeepsPanel({
    required this.jeeps,
    required this.selectedId,
    required this.waiting,
    required this.liveEnabled,
    required this.showRouteCode,
    required this.onSelected,
  });

  final List<RouteJeep> jeeps;
  final String? selectedId;
  final bool waiting;
  final bool liveEnabled;
  final bool showRouteCode;
  final ValueChanged<RouteJeep> onSelected;

  static String _metres(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  /// "1.2 km before your stop · about 5 min" / "Already passed your stop".
  static String describe(RouteJeep j) {
    final live = j.track.latest;
    if (live.isSignalLost) return 'Signal lost — showing its last known position';
    if (live.isUnavailable) return 'Driver set to unavailable';
    final plan = j.plan;
    final stop = j.leg.boardLabel;
    if (plan == null) return 'On this route now';
    if (!plan.onRoute) return '${_metres(plan.walkStraightM)} from $stop';
    final m = plan.jeepToBoardM;
    if (m == null) return 'Already passed $stop';
    if (m < 30) return 'At $stop now';
    return '${_metres(m)} before $stop · about ${jeepMinutes(m, live.speed)} min';
  }

  @override
  Widget build(BuildContext context) {
    if (!liveEnabled) return const SizedBox.shrink();
    final Widget body;
    if (waiting) {
      body = const Text('Looking for PUVs on this route…', style: TextStyle(color: AppColors.textSecondary));
    } else if (jeeps.isEmpty) {
      body = const Text(
        'No PUV on this route is sending GPS right now. They show up here as soon as one does.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    } else {
      body = SizedBox(
        height: 74,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: jeeps.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
          itemBuilder: (context, i) {
            final j = jeeps[i];
            final selected = j.vehicleId == selectedId;
            final next = j.leg.nextVehicleId == j.vehicleId;
            return Material(
              color: selected ? const Color(0xFFE3F4F4) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                side: BorderSide(color: selected ? AppColors.brandTeal : AppColors.divider, width: selected ? 2 : 1),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSpacing.xs),
                onTap: () => onSelected(j),
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_bus, size: 18, color: AppColors.brandTeal),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              showRouteCode ? '${j.plate} · ${j.leg.routeCode ?? j.leg.routeName}' : j.plate,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (next) ...[
                            const SizedBox(width: 6),
                            const Text('Next', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(describe(j),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(jeeps.isEmpty ? 'PUVs on this route' : 'PUVs on this route — tap one to follow it',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }
}

/// Fare breakdown under the map (scrollable on short screens), with the
/// "Select this route" button pinned below it.
class _FarePanel extends StatelessWidget {
  const _FarePanel({required this.option, this.onSelect});

  final RouteOption option;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final onSelect = this.onSelect;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.38),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: FareBreakdownSheet(option: option),
              ),
            ),
            if (onSelect != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
                child: FilledButton.icon(
                  key: const Key('selectThisRoute'),
                  onPressed: onSelect,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandTeal,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Select this route'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
