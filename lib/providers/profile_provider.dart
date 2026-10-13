// lib/providers/profile_provider.dart
//
// State for the commuter's Profile tab: profile + stats, saved routes and
// notification choices. Changes show immediately and are rolled back if
// the backend refuses them. Guests have no profile, so nothing loads.

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/commuter_profile.dart';
import '../models/trip_plan.dart';
import '../services/api_error.dart';
import '../services/profile_service.dart';
import 'load_state.dart';

class ProfileProvider extends ChangeNotifier {
  ProfileProvider({required ProfileService service, required this.isGuest}) : _service = service;

  final ProfileService _service;
  final bool isGuest;

  LoadState _state = LoadState.idle;
  CommuterProfile? _profile;
  List<SavedRoute> _savedRoutes = const [];
  Map<NotificationPref, bool> _prefs = NotificationPref.fromSettings(const {});
  String? _errorMessage;
  bool _disposed = false;

  LoadState get state => _state;
  CommuterProfile? get profile => _profile;
  List<SavedRoute> get savedRoutes => _savedRoutes;
  String? get errorMessage => _errorMessage;
  bool isEnabled(NotificationPref pref) => _prefs[pref] ?? false;

  Future<void> load() async {
    if (isGuest || _state == LoadState.loading) return;
    _state = LoadState.loading;
    _errorMessage = null;
    _notify();

    try {
      final results = await Future.wait([
        _service.profile(),
        _service.savedRoutes(),
        _service.notificationPrefs(),
      ]);
      _profile = results[0] as CommuterProfile;
      _savedRoutes = results[1] as List<SavedRoute>;
      _prefs = results[2] as Map<NotificationPref, bool>;
      _state = LoadState.ready;
    } catch (e) {
      _errorMessage = apiErrorMessage(e);
      _state = LoadState.error;
    }
    _notify();
  }

  /// Returns an error message, or null on success.
  Future<String?> rename(String name) async {
    try {
      _profile = await _service.updateName(name.trim());
      _notify();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> addSavedRoute({
    required String label,
    required String routeId,
    required String originName,
    required String destinationName,
    LatLng? origin,
    LatLng? destination,
  }) async {
    try {
      final saved = await _service.saveRoute(
        label: label.trim(),
        routeId: routeId,
        originName: originName,
        destinationName: destinationName,
        origin: origin,
        destination: destination,
      );
      _savedRoutes = [saved, ..._savedRoutes];
      _adjustStats(savedRoutes: 1);
      _notify();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> removeSavedRoute(SavedRoute route) async {
    final before = _savedRoutes;
    _savedRoutes = [for (final r in _savedRoutes) if (r.id != route.id) r];
    _adjustStats(savedRoutes: -1);
    _notify();
    try {
      await _service.deleteSavedRoute(route.id);
      return null;
    } catch (e) {
      _savedRoutes = before;
      _adjustStats(savedRoutes: 1);
      _notify();
      return apiErrorMessage(e);
    }
  }

  /// Returns an error message, or null on success.
  Future<String?> setNotificationPref(NotificationPref pref, bool enabled) async {
    _prefs = {..._prefs, pref: enabled};
    _notify();
    try {
      await _service.setNotificationPref(pref, enabled);
      return null;
    } catch (e) {
      _prefs = {..._prefs, pref: !enabled};
      _notify();
      return apiErrorMessage(e);
    }
  }

  /// Logs a trip the commuter set out on. Best-effort: a failure only
  /// means the Trips count misses one, so it is not shown to the user.
  Future<void> recordTrip(RouteOption option, {required String from, required String to}) async {
    if (isGuest) return;
    try {
      await _service.recordTrip(
        routeIds: [for (final leg in option.legs) leg.routeId],
        originName: from,
        destinationName: to,
        totalFare: option.totalFare,
        totalEtaMin: option.totalEtaMin,
      );
      _adjustStats(trips: 1);
      _notify();
    } catch (e) {
      debugPrint('Could not record trip: $e');
    }
  }

  void _adjustStats({int trips = 0, int savedRoutes = 0}) {
    final profile = _profile;
    if (profile == null) return;
    _profile = profile.copyWith(
      stats: profile.stats.copyWith(
        trips: profile.stats.trips + trips,
        savedRoutes: profile.stats.savedRoutes + savedRoutes,
      ),
    );
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
