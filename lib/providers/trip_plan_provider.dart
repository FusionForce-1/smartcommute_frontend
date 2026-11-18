// Trip plan provider
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_plan.dart';
import '../services/location_source.dart';
import '../services/trip_plan_service.dart';

/// Trip plan status
enum TripPlanStatus { idle, loading, success, empty, error }

/// Trip plan provider
class TripPlanProvider extends ChangeNotifier {
  /// Create trip plan
  TripPlanProvider({
    required TripPlanService service,
    required LocationSource locationSource,
    this.isGuest = false,
    Duration locateTimeout = const Duration(seconds: 25),
    Duration refreshInterval = const Duration(seconds: 45),
  })  : _service = service,
        _locationSource = locationSource,
        _locateTimeout = locateTimeout,
        _refreshInterval = refreshInterval;

  final bool isGuest;

  static const double replanDistanceMeters = 100;

  static const double alreadyThereMeters = 20;

  static const String _genericError = 'Something went wrong. Please try again.';

  final TripPlanService _service;
  final LocationSource _locationSource;
  final Duration _locateTimeout;
  final Duration _refreshInterval;

  StreamSubscription<LatLng>? _positionSub;
  Timer? _refreshTimer;
  LatLng? _plannedFrom;
  bool _isRefreshing = false;
  DateTime? _lastUpdated;
  String? _updateNotice;

  static const int maxRecentSearches = 3;

  LatLng? _origin;
  String? _originLabel;
  bool _isLocating = false;
  String? _locationError;

  LatLng? _destination;
  String? _destinationLabel;
  bool _destinationFromMap = false;
  TripPreference _preference = TripPreference.time;

  TripPlanStatus _status = TripPlanStatus.idle;
  List<RouteOption> _options = const [];
  RouteOption? _selectedOption;
  String? _errorMessage;
  final List<TripPlace> _recentSearches = [];

  int _requestId = 0;
  bool _disposed = false;

  LatLng? get origin => _origin;

  String? get originLabel => _originLabel;
  bool get isLocating => _isLocating;
  String? get locationError => _locationError;
  LatLng? get destination => _destination;
  String? get destinationLabel => _destinationLabel;

  bool get destinationFromMap => _destinationFromMap;
  TripPreference get preference => _preference;
  TripPlanStatus get status => _status;
  List<RouteOption> get options => _options;
  RouteOption? get selectedOption => _selectedOption;
  String? get errorMessage => _errorMessage;

  bool get isFollowingLocation => _positionSub != null;
  bool get isRefreshing => _isRefreshing;

  DateTime? get lastUpdated => _lastUpdated;

  String? get updateNotice => _updateNotice;

  /// Dismiss update notice
  void dismissUpdateNotice() {
    if (_updateNotice == null) return;
    _updateNotice = null;
    _notify();
  }

  List<TripPlace> get recentSearches => List.unmodifiable(_recentSearches);

  bool get canSwap => _origin != null && _destination != null && !_isLocating;

  bool get canPlan =>
      _origin != null &&
      _destination != null &&
      !_isLocating &&
      _status != TripPlanStatus.loading;

  /// Locate origin
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
    } on TimeoutException {
      _origin = null;
      _locationError = const LocationException(LocationFailure.timeout).message;
    } catch (_) {
      _origin = null;
      _locationError = 'Unable to get your current location.';
    }

    _isLocating = false;
    _notify();
  }

  bool get canOpenLocationSettings => _locationSource.canOpenSettings;

  /// Open location settings
  Future<void> openLocationSettings() => _locationSource.openSettings();

  /// Set origin
  void setOrigin(LatLng origin, String label) {
    stopLiveUpdates();
    _origin = origin;
    _originLabel = label;
    _locationError = null;
    _clearResults();
    _notify();
  }

  /// Swap origin and destination
  void swapOriginAndDestination() {
    if (!canSwap) return;
    final origin = _origin!;
    final originLabel = _originLabel ?? 'Your location';
    stopLiveUpdates();
    _origin = _destination;
    _originLabel = _destinationLabel;
    _destination = origin;
    _destinationLabel = originLabel;
    _destinationFromMap = false;
    _clearResults();
    _notify();
  }

  /// Set destination
  void setDestination(LatLng destination, String label, {bool fromMap = false}) {
    _destination = destination;
    _destinationLabel = label;
    _destinationFromMap = fromMap;
    _clearResults();
    _notify();
  }

  /// Set preference
  void setPreference(TripPreference preference) {
    if (preference == _preference) return;
    _preference = preference;
    _clearResults();
    _notify();
  }

  /// Plan trip plan
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

  /// Select option
  void selectOption(RouteOption option) {
    _selectedOption = option;
    _notify();
  }


  /// Start live updates
  void startLiveUpdates() {
    if (_positionSub != null || _originLabel != null || _disposed) return;
    _positionSub = _locationSource
        .positionStream(distanceFilterM: 25)
        .listen(_onPosition, onError: (Object _) {});
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => refresh());
    _notify();
  }

  /// Stop live updates
  void stopLiveUpdates() {
    _positionSub?.cancel();
    _positionSub = null;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// On position
  void _onPosition(LatLng position) {
    if (_originLabel != null) return;
    _origin = position;
    final from = _plannedFrom;
    if (from != null &&
        const Distance().as(LengthUnit.Meter, from, position) >= replanDistanceMeters) {
      refresh();
    }
  }

  /// Refresh trip plan
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
    } finally {
      _isRefreshing = false;
      _notify();
    }
  }

  /// Notice for
  static String? _noticeFor(RouteOption? before, RouteOption? now) {
    if (before == null || now == null) return null;
    if (now.signature != before.signature) return 'Better route now: ${now.routeSummary}';
    if (now.legs.first.boardStop.id != before.legs.first.boardStop.id) return 'Closer stop now: ${now.legs.first.boardLabel}';
    return null;
  }

  /// Remember search
  void _rememberSearch(TripPlace place) {
    if (isGuest) return;
    _recentSearches
      ..removeWhere((p) => p.label == place.label)
      ..insert(0, place);
    if (_recentSearches.length > maxRecentSearches) {
      _recentSearches.removeRange(maxRecentSearches, _recentSearches.length);
    }
  }

  /// Clear results
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

  /// Message for
  static String _messageFor(DioException e) {
    if (e.response?.statusCode == 429) {
      return 'Too many route searches. Please wait a minute and try again.';
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

  /// Notify trip plan
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _disposed = true;
    stopLiveUpdates();
    super.dispose();
  }
}
