// lib/providers/driver_provider.dart
//
// State behind the Driver Dashboard: who the driver is, the vehicle they
// drive, their shift, duty status, crowd and passenger reports, the GPS
// broadcast, and the next stop / ETA the backend works out from it.
//
// Taps update the screen straight away and are rolled back if the server
// refuses them. Actions return null on success or a message to show.

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/driver_dashboard.dart';
import '../models/vehicle_live_update.dart';
import '../services/api_error.dart';
import '../services/driver_service.dart';
import '../services/websocket_service.dart';
import 'load_state.dart';

class DriverProvider extends ChangeNotifier {
  DriverProvider(
    this._service, {
    GpsIngestionSession? gps,
    WebSocketService? liveFeed,
  })  : gps = gps ?? GpsIngestionSession(accessToken: _service.freshAccessToken),
        _liveFeed = liveFeed {
    this.gps.addListener(notifyListeners);
  }

  final DriverService _service;

  /// For screens that load extra data, e.g. the route line on the map.
  DriverService get service => _service;

  /// Streams this device's location for the shift's vehicle.
  final GpsIngestionSession gps;

  /// Commuter-side broadcast, used here for our own vehicle's next stop.
  final WebSocketService? _liveFeed;

  static const String noShiftMessage = 'Start your shift first.';
  static const String noTrackerMessage =
      'No GPS tracker is set up for this vehicle. Ask your operator.';

  LoadState _loadState = LoadState.idle;
  String? _loadError;
  DriverDashboardData? _data;
  String? _selectedVehicleId;
  DriverShift? _shift;
  DutyStatus _dutyStatus = DutyStatus.unavailable;
  int _crowdPercent = 0;
  bool _busy = false;
  VehicleLiveUpdate? _live;
  bool _liveStarted = false;

  LoadState get loadState => _loadState;
  String? get loadError => _loadError;
  String get name => _data?.name ?? '';
  List<AssignedVehicle> get vehicles => _data?.vehicles ?? const [];
  DriverShift? get shift => _shift;
  bool get onShift => _shift != null;
  DutyStatus get dutyStatus => _dutyStatus;
  int get crowdPercent => _crowdPercent;

  /// True while a shift is starting or ending.
  bool get busy => _busy;

  bool get broadcasting => gps.isActive;

  /// Kilometres driven this shift: what the server had stored when the
  /// dashboard loaded, plus the hops this device has sent since.
  double get distanceKm {
    final shift = _shift;
    return shift == null ? 0 : shift.distanceKm + gps.distanceMetres / 1000;
  }

  /// The vehicle being driven (during a shift) or picked for the next one.
  AssignedVehicle? get vehicle {
    final id = _shift?.vehicleId ?? _selectedVehicleId;
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Next stop and ETA for our vehicle, once it is broadcasting.
  VehicleLiveUpdate? get live => _live?.vehicleId == vehicle?.id ? _live : null;

  // ── Loading ─────────────────────────────────────────────────

  Future<void> load() async {
    final firstLoad = _data == null;
    if (firstLoad) {
      _loadState = LoadState.loading;
      notifyListeners();
    }
    try {
      final data = await _service.dashboard();
      _data = data;
      _shift = data.shift;
      // The server's distance already covers what this device sent.
      gps.resetDistance();
      _dutyStatus = data.dutyStatus;
      _crowdPercent = data.shift?.crowdPercent ?? 0;
      final ids = data.vehicles.map((v) => v.id);
      if (!ids.contains(_selectedVehicleId)) {
        _selectedVehicleId = data.vehicles.isEmpty ? null : data.vehicles.first.id;
      }
      _loadState = LoadState.ready;
      _loadError = null;
      _listenForLiveUpdates();
    } catch (e) {
      _loadError = apiErrorMessage(e);
      if (_data == null) _loadState = LoadState.error;
    }
    notifyListeners();

    // A shift still running from before the app was closed or reloaded:
    // without GPS its distance and trips can't be worked out. Only on
    // opening, so a refresh doesn't undo the driver switching it off.
    if (firstLoad && onShift && !gps.isActive) await setBroadcasting(true);
  }

  void selectVehicle(String id) {
    if (onShift || id == _selectedVehicleId) return;
    _selectedVehicleId = id;
    notifyListeners();
  }

  // ── Shift ───────────────────────────────────────────────────

  /// Starts a shift on the picked vehicle and turns on the GPS broadcast.
  Future<String?> startShift() async {
    final vehicleId = vehicle?.id;
    if (vehicleId == null) return 'No vehicle is assigned to you yet. Ask your operator.';
    if (_busy) return null;
    _setBusy(true);
    try {
      _shift = await _service.startShift(vehicleId);
      gps.resetDistance();
      _dutyStatus = DutyStatus.onRoute;
      _crowdPercent = 0;
    } catch (e) {
      _setBusy(false);
      return apiErrorMessage(e);
    }
    _setBusy(false);

    final gpsError = await setBroadcasting(true);
    return gpsError == null ? null : 'Shift started, but GPS is off: $gpsError';
  }

  /// Stops the broadcast and ends the shift. Returns its summary, or an error.
  Future<({ShiftSummary? summary, String? error})> endShift() async {
    if (!onShift) return (summary: null, error: noShiftMessage);
    _setBusy(true);
    await gps.stop();
    try {
      final summary = await _service.endShift();
      _shift = null;
      _dutyStatus = DutyStatus.unavailable;
      _crowdPercent = 0;
      _live = null;
      return (summary: summary, error: null);
    } catch (e) {
      return (summary: null, error: apiErrorMessage(e));
    } finally {
      _setBusy(false);
    }
  }

  // ── Reports during a shift ──────────────────────────────────

  Future<String?> setDutyStatus(DutyStatus status) async {
    if (status == _dutyStatus) return null;
    if (!onShift && status != DutyStatus.unavailable) return noShiftMessage;
    final previous = _dutyStatus;
    _dutyStatus = status;
    notifyListeners();
    try {
      await _service.setDutyStatus(status);
      return null;
    } catch (e) {
      _dutyStatus = previous;
      notifyListeners();
      return apiErrorMessage(e);
    }
  }

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

  /// Turns the GPS broadcast on or off; only during a shift, and only on a
  /// vehicle with a GPS tracker set up.
  Future<String?> setBroadcasting(bool on) async {
    final vehicleId = _shift?.vehicleId;
    if (on && vehicleId == null) return noShiftMessage;
    if (on && !canBroadcast) return noTrackerMessage;
    if (!on) {
      await gps.stop();
      return null;
    }
    try {
      await gps.start(vehicleId!);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  // ── Internals ───────────────────────────────────────────────

  void _listenForLiveUpdates() {
    final feed = _liveFeed;
    if (feed == null || _liveStarted) return;
    _liveStarted = true;
    feed.connect();
    feed.listenForMessages((message) {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      final update = VehicleLiveUpdate.fromJson(json);
      if (update.vehicleId != vehicle?.id) return;
      final current = _live;
      // merge() returns null for an older fix that arrived late.
      final next = current == null || current.vehicleId != update.vehicleId ? update : current.merge(update);
      if (next == null) return;
      _live = next;
      notifyListeners();
    });
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    gps.removeListener(notifyListeners);
    gps.dispose();
    _liveFeed?.disconnect();
    super.dispose();
  }
}
