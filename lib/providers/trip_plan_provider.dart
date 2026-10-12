// lib/providers/trip_plan_provider.dart
//
// State sa Trip Planner: GPS origin, destination, preference, results.
// Gi-own sa CommuterDashboard para mabasa sa "View fare estimate" tile
// ang selectedOption bisan sirado na ang planner screen.
//
// Live updates (startLiveUpdates): while the results are on screen and the
// origin is the commuter's GPS, the plan is quietly refreshed when they've
// moved [replanDistanceMeters] and every [refreshInterval] (so live jeep
// waits stay current). Their selected option is kept when it's still offered.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_plan.dart';
import '../services/location_source.dart';
import '../services/trip_plan_service.dart';

enum TripPlanStatus { idle, loading, success, empty, error }

class TripPlanProvider extends ChangeNotifier {
  TripPlanProvider({
    required TripPlanService service,
    required LocationSource locationSource,
    Duration locateTimeout = const Duration(seconds: 15),
    Duration refreshInterval = const Duration(seconds: 45),
  })  : _service = service,
        _locationSource = locationSource,
        _locateTimeout = locateTimeout,
        _refreshInterval = refreshInterval;

  /// Re-plan once the commuter is this far from where the plan was made.
  static const double replanDistanceMeters = 100;

  /// Kung ingon ani ka duol ang destination, naa na sila.
  static const double alreadyThereMeters = 20;

  static const String _genericError = 'Something went wrong. Please try again.';

  final TripPlanService _service;
  final LocationSource _locationSource;
  // Kung walay GPS fix (e.g. sulod sa building), dili mag-spin forever.
  final Duration _locateTimeout;
  final Duration _refreshInterval;

  StreamSubscription<LatLng>? _positionSub;
  Timer? _refreshTimer;
  LatLng? _plannedFrom;
  bool _isRefreshing = false;
  DateTime? _lastUpdated;
  String? _updateNotice;

  /// Kapila ka recent search ang i-display.
  static const int maxRecentSearches = 3;

  LatLng? _origin;
  // null = ang GPS location sa commuter; kung naa, stop nga gipili.
  String? _originLabel;
  bool _isLocating = false;
  String? _locationError;

  LatLng? _destination;
  String? _destinationLabel;
  TripPreference _preference = TripPreference.time;

  TripPlanStatus _status = TripPlanStatus.idle;
  List<RouteOption> _options = const [];
  RouteOption? _selectedOption;
  String? _errorMessage;
  final List<TripPlace> _recentSearches = [];

  // Mo-increment kada clear para ma-ignore ang daan nga response.
  int _requestId = 0;
  bool _disposed = false;

  LatLng? get origin => _origin;

  /// Stop name for a chosen origin; null when the origin is the GPS location.
  String? get originLabel => _originLabel;
  bool get isLocating => _isLocating;
  String? get locationError => _locationError;
  LatLng? get destination => _destination;
  String? get destinationLabel => _destinationLabel;
  TripPreference get preference => _preference;
  TripPlanStatus get status => _status;
  List<RouteOption> get options => _options;
  RouteOption? get selectedOption => _selectedOption;
  String? get errorMessage => _errorMessage;

  /// True while following the commuter's location (see [startLiveUpdates]).
  bool get isFollowingLocation => _positionSub != null;
  bool get isRefreshing => _isRefreshing;

  /// When the shown options were last fetched.
  DateTime? get lastUpdated => _lastUpdated;

  /// E.g. "Closer stop now: Capitol" after a refresh changed the best option.
  String? get updateNotice => _updateNotice;

  void dismissUpdateNotice() {
    if (_updateNotice == null) return;
    _updateNotice = null;
    _notify();
  }

  /// Newest first, session only.
  List<TripPlace> get recentSearches => List.unmodifiable(_recentSearches);

  bool get canSwap => _origin != null && _destination != null && !_isLocating;

  bool get canPlan =>
      _origin != null &&
      _destination != null &&
      !_isLocating &&
      _status != TripPlanStatus.loading;

  Future<void> locateOrigin() async {
    if (_isLocating) return;
    _isLocating = true;
    _locationError = null;
    _notify();

    try {
      _origin = await _locationSource.currentLocation().timeout(_locateTimeout);
      _originLabel = null;
      _clearResults();
    } on LocationException catch (e) {
      _origin = null;
      _locationError = e.message;
    } catch (_) {
      _origin = null;
      _locationError = 'Unable to get your current location.';
    }

    _isLocating = false;
    _notify();
  }

  bool get canOpenLocationSettings => _locationSource.canOpenSettings;

  Future<void> openLocationSettings() => _locationSource.openSettings();

  /// Start from a chosen stop instead of the GPS location.
  void setOrigin(LatLng origin, String label) {
    stopLiveUpdates(); // a chosen stop doesn't move
    _origin = origin;
    _originLabel = label;
    _locationError = null;
    _clearResults();
    _notify();
  }

  void swapOriginAndDestination() {
    if (!canSwap) return;
    final origin = _origin!;
    final originLabel = _originLabel ?? 'Your location';
    stopLiveUpdates();
    _origin = _destination;
    _originLabel = _destinationLabel;
    _destination = origin;
    _destinationLabel = originLabel;
    _clearResults();
    _notify();
  }

  void setDestination(LatLng destination, String label) {
    _destination = destination;
    _destinationLabel = label;
    _clearResults();
    _notify();
  }

  void setPreference(TripPreference preference) {
    if (preference == _preference) return;
    _preference = preference;
    _clearResults();
    _notify();
  }

  Future<void> plan() async {
    if (!canPlan) return;
    final origin = _origin!;
    final destination = _destination!;

    _clearResults();
    if (const Distance().as(LengthUnit.Meter, origin, destination) <
        alreadyThereMeters) {
      _status = TripPlanStatus.error;
      _errorMessage = "You're already there.";
      _notify();
      return;
    }

    _rememberSearch(TripPlace(
      location: destination,
      label: _destinationLabel ?? 'Dropped pin',
    ));
    final requestId = _requestId;
    _status = TripPlanStatus.loading;
    _notify();

    try {
      final response = await _service.planTrip(
        origin: origin,
        destination: destination,
        preference: _preference,
      );
      if (requestId != _requestId) return;
      _options = response.options;
      _status = _options.isEmpty ? TripPlanStatus.empty : TripPlanStatus.success;
      // Best-ranked option starts selected.
      _selectedOption = _options.isEmpty ? null : _options.first;
      _plannedFrom = origin;
      _lastUpdated = DateTime.now();
    } on DioException catch (e) {
      if (requestId != _requestId) return;
      _status = TripPlanStatus.error;
      _errorMessage = _messageFor(e);
    } catch (_) {
      if (requestId != _requestId) return;
      _status = TripPlanStatus.error;
      _errorMessage = _genericError;
    }
    _notify();
  }

  void selectOption(RouteOption option) {
    _selectedOption = option;
    _notify();
  }

  // ── Live updates ──────────────────────────────────────────

  /// Follows the commuter's GPS and keeps the plan current. Only for a GPS
  /// origin; a chosen stop as origin doesn't move. Call [stopLiveUpdates]
  /// when the results leave the screen.
  void startLiveUpdates() {
    if (_positionSub != null || _originLabel != null || _disposed) return;
    _positionSub = _locationSource
        .positionStream(distanceFilterM: 25)
        .listen(_onPosition, onError: (Object _) {});
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
    _notify();
  }

  void stopLiveUpdates() {
    _positionSub?.cancel();
    _positionSub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _onPosition(LatLng position) {
    if (_originLabel != null) return;
    _origin = position;
    final from = _plannedFrom;
    if (from != null &&
        const Distance().as(LengthUnit.Meter, from, position) >= replanDistanceMeters) {
      refresh();
    }
  }

  /// Re-plans without the loading state, keeping the current results on
  /// screen. A failed background refresh keeps the last results.
  Future<void> refresh() async {
    final origin = _origin;
    final destination = _destination;
    if (_isRefreshing || origin == null || destination == null) return;
    if (_status != TripPlanStatus.success && _status != TripPlanStatus.empty) return;

    final requestId = _requestId;
    _isRefreshing = true;
    _notify();
    try {
      final response = await _service.planTrip(
        origin: origin,
        destination: destination,
        preference: _preference,
      );
      if (requestId != _requestId) return;

      final previousBest = _options.isEmpty ? null : _options.first;
      final selectedSignature = _selectedOption?.signature;
      _options = response.options;
      _status = _options.isEmpty ? TripPlanStatus.empty : TripPlanStatus.success;
      _selectedOption = _options.isEmpty
          ? null
          : _options.firstWhere((o) => o.signature == selectedSignature,
              orElse: () => _options.first);
      _plannedFrom = origin;
      _lastUpdated = DateTime.now();
      _updateNotice = _noticeFor(previousBest, _options.isEmpty ? null : _options.first);
    } catch (_) {
      // Keep showing the last results.
    } finally {
      _isRefreshing = false;
      _notify();
    }
  }

  static String? _noticeFor(RouteOption? before, RouteOption? now) {
    if (before == null || now == null) return null;
    if (now.signature != before.signature) return 'Better route now: ${now.routeSummary}';
    if (now.legs.first.boardStop.id != before.legs.first.boardStop.id) return 'Closer stop now: ${now.legs.first.boardLabel}';
    return null;
  }

  void _rememberSearch(TripPlace place) {
    _recentSearches
      ..removeWhere((p) => p.label == place.label)
      ..insert(0, place);
    if (_recentSearches.length > maxRecentSearches) {
      _recentSearches.removeRange(maxRecentSearches, _recentSearches.length);
    }
  }

  void _clearResults() {
    _requestId++;
    _plannedFrom = null;
    _updateNotice = null;
    _lastUpdated = null;
    _status = TripPlanStatus.idle;
    _options = const [];
    _selectedOption = null;
    _errorMessage = null;
  }

  static String _messageFor(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) {
      return 'Sign in as a commuter to plan trips.';
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return "Can't reach the server. Check your connection.";
      default:
        return _genericError;
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopLiveUpdates();
    super.dispose();
  }
}
