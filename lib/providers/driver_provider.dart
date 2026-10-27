// lib/providers/driver_provider.dart
//
// State behind the Driver Dashboard: who the driver is, their assigned
// vehicles and routes, the shift their operator started, crowd and
// passenger reports during it, and their updates (notifications).
//
// The operator starts and ends shifts in the portal; [refresh] (every
// [refreshInterval] once [startAutoRefresh] is called, and right away when
// the live feed says the shift ended) follows them. While a shift is open
// the phone shares its location as a backup: the backend only uses it while
// the jeep's tracker is offline. Which of the two the jeep's position is
// coming from is read from the live feed ([jeepGps]).
//
// Crowd and passenger taps update the screen straight away and are rolled
// back if the server refuses them. Actions return null on success or a
// message to show.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/driver_dashboard.dart';
import '../models/transport_model.dart';
import '../models/vehicle_live_update.dart';
import '../services/api_error.dart';
import '../services/driver_service.dart';
import '../services/websocket_service.dart';
import 'load_state.dart';

/// Where the jeep's live position is coming from.
enum JeepGps { tracker, phone, none }

class DriverProvider extends ChangeNotifier {
  DriverProvider(
    this._service, {
    GpsIngestionSession? gps,
    WebSocketService? liveFeed,
    this.refreshInterval = const Duration(seconds: 20),
    DateTime Function()? clock,
  })  : gps = gps ?? GpsIngestionSession(accessToken: _service.freshAccessToken),
        _liveFeed = liveFeed,
        _now = clock ?? DateTime.now {
    this.gps.addListener(notifyListeners);
  }

  final DriverService _service;

  /// The phone's GPS, shared while a shift is open (the tracker's backup).
  final GpsIngestionSession gps;

  /// Commuter-side broadcast, used here for our own jeep.
  final WebSocketService? _liveFeed;

  final Duration refreshInterval;
  final DateTime Function() _now;

  static const String noShiftMessage = "Your operator hasn't started your shift yet.";
  static const String noTrackerMessage = 'No GPS tracker is set up for this jeep, so your phone has nothing to back up. Ask your operator.';

  /// No live fix for this long and the jeep counts as having no GPS.
  static const Duration liveFresh = Duration(seconds: 30);

  LoadState _loadState = LoadState.idle;
  String? _loadError;
  DriverDashboardData? _data;
  DriverShift? _shift;
  int _crowdPercent = 0;
  List<DriverUpdate> _updates = const [];
  VehicleLiveUpdate? _live;
  DateTime? _liveAt;
  String? _gpsError;
  bool _liveStarted = false;
  bool _refreshing = false;
  Timer? _timer;
  final Map<String, Future<TransportRoute?>> _routeLines = {};

  LoadState get loadState => _loadState;
  String? get loadError => _loadError;
  String get name => _data?.name ?? '';
  List<AssignedVehicle> get vehicles => _data?.vehicles ?? const [];
  DriverShift? get shift => _shift;
  bool get onShift => _shift != null;
  int get crowdPercent => _crowdPercent;
  List<DriverUpdate> get updates => _updates;
  int get unreadUpdates => _updates.where((u) => !u.isRead).length;

  /// Why the phone isn't sharing its location (e.g. permission denied), if so.
  String? get gpsError => _gpsError;

  /// The shift's vehicle, else the first one assigned.
  AssignedVehicle? get vehicle {
    final list = vehicles;
    final id = _shift?.vehicleId;
    for (final v in list) {
      if (v.id == id) return v;
    }
    return list.isEmpty ? null : list.first;
  }

  /// Our jeep's latest live frame (position, next stop, ETA).
  VehicleLiveUpdate? get live => _live?.vehicleId == vehicle?.id ? _live : null;

  JeepGps get jeepGps {
    final live = this.live;
    final at = _liveAt;
    if (live == null || at == null || live.isSignalLost || _now().difference(at) > liveFresh) {
      return JeepGps.none;
    }
    return live.source == 'phone' ? JeepGps.phone : JeepGps.tracker;
  }

  // ── Loading ─────────────────────────────────────────────────

  /// Loads the dashboard (a spinner the first time only) and follows the shift.
  Future<void> load() async {
    if (_refreshing) return;
    _refreshing = true;
    if (_data == null) {
      _loadState = LoadState.loading;
      notifyListeners();
    }
    try {
      final data = await _service.dashboard();
      final shiftChanged = data.shift?.id != _shift?.id;
      _data = data;
      _shift = data.shift;
      if (shiftChanged) {
        _crowdPercent = data.shift?.crowdPercent ?? 0;
        if (data.shift == null) _live = null;
      }
      _loadState = LoadState.ready;
      _loadError = null;
      _listenForLiveUpdates();
      notifyListeners();
      await _syncPhoneGps();
      await loadUpdates();
    } catch (e) {
      _loadError = apiErrorMessage(e);
      if (_data == null) _loadState = LoadState.error;
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  /// Same as [load]: the operator may have started or ended the shift.
  Future<void> refresh() => load();

  /// Checks for shift changes every [refreshInterval] while the dashboard is open.
  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  Future<void> loadUpdates() async {
    try {
      _updates = await _service.updates();
      notifyListeners();
    } catch (_) {
      // Updates are extra: keep showing the last ones.
    }
  }

  Future<void> markUpdatesRead() async {
    if (unreadUpdates == 0) return;
    final before = _updates;
    _updates = [
      for (final u in _updates)
        DriverUpdate(id: u.id, kind: u.kind, title: u.title, body: u.body, createdAt: u.createdAt, isRead: true),
    ];
    notifyListeners();
    try {
      await _service.markUpdatesRead();
    } catch (_) {
      _updates = before;
      notifyListeners();
    }
  }

  /// The route's line and stops for the map, fetched once; null if it has none
  /// (a failed fetch is tried again next time).
  Future<TransportRoute?> routeLine(String routeId) {
    return _routeLines[routeId] ??= _service.route(routeId).then<TransportRoute?>(
      (route) => route,
      onError: (Object _) {
        _routeLines.remove(routeId);
        return null;
      },
    );
  }

  // ── Phone GPS (the tracker's backup) ────────────────────────

  Future<void> _syncPhoneGps() async {
    final shift = _shift;
    if (shift == null) {
      if (gps.isActive) await gps.stop();
      _gpsError = null;
      return;
    }
    if (vehicle?.hasTracker != true) {   // the backend only takes a phone's GPS as a tracker's backup
      if (gps.isActive) await gps.stop();
      _gpsError = noTrackerMessage;
      return;
    }
    if (gps.isActive || _gpsError != null) return;   // a refused permission isn't asked again by itself
    try {
      await gps.start(shift.vehicleId);
    } catch (e) {
      _gpsError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// "Try again" after turning location on.
  Future<void> retryPhoneGps() async {
    _gpsError = null;
    notifyListeners();
    await _syncPhoneGps();
  }

  // ── Reports during a shift ──────────────────────────────────

  /// Moves the slider without saving (called while dragging).
  void previewCrowd(int percent) {
    if (!onShift) return;
    _crowdPercent = percent;
    notifyListeners();
  }

  /// Saves where the slider was let go.
  Future<String?> commitCrowd(int percent) async {
    final shift = _shift;
    if (shift == null) return noShiftMessage;
    _crowdPercent = percent;
    notifyListeners();
    try {
      await _service.reportCrowd(percent);
      _shift = shift.copyWith(crowdPercent: percent);
      return null;
    } catch (e) {
      _crowdPercent = shift.crowdPercent;
      notifyListeners();
      return apiErrorMessage(e);
    }
  }

  /// +1 when a passenger boards; -1 to undo a mistaken tap.
  Future<String?> changePassengers(int change) async {
    final shift = _shift;
    if (shift == null) return noShiftMessage;
    _shift = shift.copyWith(passengers: max(0, shift.passengers + change));
    notifyListeners();
    try {
      final count = await _service.changePassengers(change);
      _shift = _shift?.copyWith(passengers: count);
      notifyListeners();
      return null;
    } catch (e) {
      _shift = _shift?.copyWith(passengers: shift.passengers);
      notifyListeners();
      return apiErrorMessage(e);
    }
  }

  // ── Live feed ───────────────────────────────────────────────

  void _listenForLiveUpdates() {
    final feed = _liveFeed;
    if (feed == null || _liveStarted) return;
    _liveStarted = true;
    feed.connect();
    feed.listenForMessages((message) {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      if (json['vehicle_id'] is! String) return;   // e.g. transit alerts
      onLiveFrame(VehicleLiveUpdate.fromJson(json));
    });
  }

  /// One frame from the live feed (public for tests).
  @visibleForTesting
  void onLiveFrame(VehicleLiveUpdate update) {
    if (update.vehicleId != vehicle?.id) return;
    if (update.shiftEnded) {
      unawaited(refresh());   // the operator ended the shift
      return;
    }
    final current = _live;
    // merge() returns null for an older fix that arrived late.
    final next = current == null || current.vehicleId != update.vehicleId ? update : current.merge(update);
    if (next == null) return;
    _live = next;
    if (update.location != null) _liveAt = _now();
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    gps.removeListener(notifyListeners);
    gps.dispose();
    _liveFeed?.disconnect();
    super.dispose();
  }
}
