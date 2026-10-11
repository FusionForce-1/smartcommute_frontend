// lib/providers/trip_plan_provider.dart
//
// State sa Trip Planner: GPS origin, destination, preference, results.
// Gi-own sa CommuterDashboard para mabasa sa "View fare estimate" tile
// ang selectedOption bisan sirado na ang planner screen.

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
  })  : _service = service,
        _locationSource = locationSource,
        _locateTimeout = locateTimeout;

  /// Kung ingon ani ka duol ang destination, naa na sila.
  static const double alreadyThereMeters = 20;

  static const String _genericError = 'Something went wrong. Please try again.';

  final TripPlanService _service;
  final LocationSource _locationSource;
  // Kung walay GPS fix (e.g. sulod sa building), dili mag-spin forever.
  final Duration _locateTimeout;

  LatLng? _origin;
  bool _isLocating = false;
  String? _locationError;

  LatLng? _destination;
  String? _destinationLabel;
  TripPreference _preference = TripPreference.time;

  TripPlanStatus _status = TripPlanStatus.idle;
  List<RouteOption> _options = const [];
  RouteOption? _selectedOption;
  String? _errorMessage;

  // Mo-increment kada clear para ma-ignore ang daan nga response.
  int _requestId = 0;
  bool _disposed = false;

  LatLng? get origin => _origin;
  bool get isLocating => _isLocating;
  String? get locationError => _locationError;
  LatLng? get destination => _destination;
  String? get destinationLabel => _destinationLabel;
  TripPreference get preference => _preference;
  TripPlanStatus get status => _status;
  List<RouteOption> get options => _options;
  RouteOption? get selectedOption => _selectedOption;
  String? get errorMessage => _errorMessage;

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

  void _clearResults() {
    _requestId++;
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
    super.dispose();
  }
}
