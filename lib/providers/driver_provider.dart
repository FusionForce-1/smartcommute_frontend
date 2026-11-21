// Driver provider
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/driver_dashboard.dart';
import '../models/driver_report.dart';
import '../models/transport_model.dart';
import '../models/vehicle_live_update.dart';
import '../services/api_error.dart';
import '../services/driver_service.dart';
import '../services/websocket_service.dart';
import 'load_state.dart';

/// Jeep GPS options
enum JeepGps { tracker, phone, none }

/// Driver provider
class DriverProvider extends ChangeNotifier {
  /// Create driver
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

  final GpsIngestionSession gps;

  final WebSocketService? _liveFeed;

  final Duration refreshInterval;
  final DateTime Function() _now;

  static const String noShiftMessage = "Your operator hasn't started your shift yet.";
  static const String noTrackerMessage = 'No GPS tracker is set up for this jeep, so your phone has nothing to back up. Ask your operator.';

  static const Duration liveFresh = Duration(seconds: 30);

  LoadState _loadState = LoadState.idle;
  String? _loadError;
  DriverDashboardData? _data;
  DriverShift? _shift;
  int _crowdPercent = 0;
  RouteStatus _routeStatus = RouteStatus.unavailable;
  List<DriverReport> _reports = const [];
  ReportsPeriod _reportsPeriod = ReportsPeriod.recent;
  DateTime? _reportsDay;
  bool _reportsLoading = false;
  TransportRoute? _route;
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
  String? get email => _data?.email;
  DriverOperator? get operator => _data?.operator;
  AssignedVehicle? get recentRoute => _data?.recentRoute;
  RouteStatus get routeStatus => onShift ? _routeStatus : RouteStatus.unavailable;
  ReportsPeriod get reportsPeriod => _reportsPeriod;

  DateTime? get reportsDay => _reportsDay;
  bool get reportsLoading => _reportsLoading;
  List<AssignedVehicle> get vehicles => _data?.vehicles ?? const [];
  DriverShift? get shift => _shift;
  bool get onShift => _shift != null;
  int get crowdPercent => _crowdPercent;

  List<DriverReport> get reports => _reports;

  String? get gpsError => _gpsError;

  AssignedVehicle? get vehicle {
    final list = vehicles;
    final id = _shift?.vehicleId;
    for (final v in list) {
      if (v.id == id) return v;
    }
    return list.isEmpty ? null : list.first;
  }

  VehicleLiveUpdate? get live => _live?.vehicleId == vehicle?.id ? _live : null;

  JeepGps get jeepGps {
    final live = this.live;
    final at = _liveAt;
    if (live == null || at == null || live.isSignalLost || _now().difference(at) > liveFresh) {
      return JeepGps.none;
    }
    return live.source == 'phone' ? JeepGps.phone : JeepGps.tracker;
  }


  /// Load driver
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
      _routeStatus = data.routeStatus;
      _loadState = LoadState.ready;
      _loadError = null;
      _listenForLiveUpdates();
      notifyListeners();
      unawaited(_loadCurrentRoute());
      await _syncPhoneGps();
      await loadReports();
    } catch (e) {
      _loadError = apiErrorMessage(e);
      if (_data == null) _loadState = LoadState.error;
      notifyListeners();
    } finally {
      _refreshing = false;
    }
  }

  /// Refresh driver
  Future<void> refresh() => load();

  /// Start auto refresh
  void startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(refreshInterval, (_) => refresh());
  }

  /// Load reports
  Future<void> loadReports() async {
    final period = _reportsPeriod;
    final day = _reportsDay;
    final range = reportsRange(period, _now(), day: day);
    _reportsLoading = true;
    notifyListeners();
    try {
      final list = await _service.sentReports(since: range.since, until: range.until);
      if (period == _reportsPeriod && day == _reportsDay) _reports = list;
    } catch (_) {
    } finally {
      _reportsLoading = false;
      notifyListeners();
    }
  }

  /// Show reports
  Future<void> showReports(ReportsPeriod period, {DateTime? day}) {
    _reportsPeriod = period;
    _reportsDay = period == ReportsPeriod.day ? day : null;
    return loadReports();
  }

  Future<({DriverReport? sent, String? error})> sendReport(
    DriverReportCategory category, {
    String? note,
    required String requestId,
  }) async {
    try {
      final sent = await _service.sendReport(category: category, note: note, requestId: requestId);
      unawaited(loadReports());
      return (sent: sent, error: null);
    } catch (e) {
      return (sent: null, error: apiErrorMessage(e));
    }
  }

  /// Route line
  Future<TransportRoute?> routeLine(String routeId) {
    return _routeLines[routeId] ??= _service.route(routeId).then<TransportRoute?>(
      (route) => route,
      onError: (Object _) {
        _routeLines.remove(routeId);
        return null;
      },
    );
  }

  TransportRoute? get route => _route?.id == vehicle?.routeId ? _route : null;

  /// Load current route
  Future<void> _loadCurrentRoute() async {
    final routeId = vehicle?.routeId;
    if (routeId == null || routeId.isEmpty || _route?.id == routeId) return;
    final line = await routeLine(routeId);
    if (line != null && routeId == vehicle?.routeId) {
      _route = line;
      notifyListeners();
    }
  }

  LatLng? get jeepPosition {
    if (jeepGps != JeepGps.none) return live?.location;
    final fix = gps.lastFix;
    return fix == null ? live?.location : LatLng(fix.latitude, fix.longitude);
  }

  double? get distanceToNextStopM {
    final name = live?.nextStop;
    final at = jeepPosition;
    final stops = route?.stops;
    if (name == null || at == null || stops == null) return null;
    for (final stop in stops) {
      if (stop.name == name) return const Distance().as(LengthUnit.Meter, at, stop.location);
    }
    return null;
  }


  /// Sync phone GPS
  Future<void> _syncPhoneGps() async {
    final shift = _shift;
    if (shift == null) {
      if (gps.isActive) await gps.stop();
      _gpsError = null;
      return;
    }
    if (vehicle?.hasTracker != true) {
      if (gps.isActive) await gps.stop();
      _gpsError = noTrackerMessage;
      return;
    }
    if (_gpsError == noTrackerMessage) _gpsError = null;
    if (gps.isActive && gps.vehicleId != shift.vehicleId) await gps.stop();
    if (gps.isActive || _gpsError != null) return;
    try {
      await gps.start(shift.vehicleId);
    } catch (e) {
      _gpsError = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  /// Retry phone GPS
  Future<void> retryPhoneGps() async {
    _gpsError = null;
    notifyListeners();
    await _syncPhoneGps();
  }


  /// Preview crowd
  void previewCrowd(int percent) {
    if (!onShift) return;
    _crowdPercent = percent;
    notifyListeners();
  }

  /// Commit crowd
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

  /// Set route status
  Future<String?> setRouteStatus(RouteStatus status) async {
    if (!onShift) return noShiftMessage;
    final before = _routeStatus;
    if (status == before) return null;
    _routeStatus = status;
    notifyListeners();
    try {
      await _service.setRouteStatus(status);
      return null;
    } catch (e) {
      _routeStatus = before;
      notifyListeners();
      return apiErrorMessage(e);
    }
  }

  bool? _trafficReported;

  bool? get trafficReported => onShift ? _trafficReported : null;

  /// Report route traffic
  Future<String?> reportTraffic(bool congested) async {
    final routeId = vehicle?.routeId;
    if (!onShift || routeId == null || routeId.isEmpty) return noShiftMessage;
    try {
      await _service.reportTraffic(routeId, congested: congested);
      _trafficReported = congested;
      notifyListeners();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Change passengers
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


  /// Listen for live updates
  void _listenForLiveUpdates() {
    final feed = _liveFeed;
    if (feed == null || _liveStarted) return;
    _liveStarted = true;
    feed.connect();
    feed.listenForMessages((message) {
      final json = jsonDecode(message as String) as Map<String, dynamic>;
      if (json['vehicle_id'] is! String) return;
      onLiveFrame(VehicleLiveUpdate.fromJson(json));
    });
  }

  /// On live frame
  @visibleForTesting
  void onLiveFrame(VehicleLiveUpdate update) {
    if (update.vehicleId != vehicle?.id) return;
    if (update.shiftEnded) {
      unawaited(refresh());
      return;
    }
    final current = _live;
    final next = current == null || current.vehicleId != update.vehicleId ? update : current.merge(update);
    if (next == null) return;
    _live = next;
    if (update.location != null) _liveAt = _now();
    notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _timer?.cancel();
    gps.removeListener(notifyListeners);
    gps.dispose();
    _liveFeed?.disconnect();
    super.dispose();
  }
}
