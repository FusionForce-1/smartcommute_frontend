// Profile provider
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../models/commuter_profile.dart';
import '../models/ride_review.dart';
import '../models/trip_plan.dart';
import '../services/api_error.dart';
import '../services/profile_service.dart';
import 'load_state.dart';

/// Profile provider
class ProfileProvider extends ChangeNotifier {
  /// Create profile
  ProfileProvider({required ProfileService service, required this.isGuest}) : _service = service;

  final ProfileService _service;
  final bool isGuest;

  LoadState _state = LoadState.idle;
  CommuterProfile? _profile;
  List<SavedRoute> _savedRoutes = const [];
  List<RideReview> _reviews = const [];
  Map<NotificationPref, bool> _prefs = NotificationPref.fromSettings(const {});
  String? _errorMessage;
  bool _disposed = false;

  ProfileService get service => _service;

  LoadState get state => _state;
  CommuterProfile? get profile => _profile;
  List<SavedRoute> get savedRoutes => _savedRoutes;

  List<RideReview> get reviews => _reviews;
  String? get errorMessage => _errorMessage;
  /// Is enabled?
  bool isEnabled(NotificationPref pref) => _prefs[pref] ?? false;

  /// Load profile
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
    try {
      _reviews = await _service.myReviews();
      _notify();
    } catch (e) {
      debugPrint('Could not load reviews: $e');
    }
  }

  /// Submit review
  Future<String?> submitReview({
    required String routeId,
    String? vehicleId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    try {
      final review = await _service.submitReview(
        routeId: routeId, vehicleId: vehicleId, rating: rating, tags: tags, comment: comment,
      );
      _reviews = [review, ..._reviews];
      _adjustStats(reviews: 1);
      _notify();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Profile rename
  Future<String?> rename(String name) async {
    try {
      _profile = await _service.updateName(name.trim());
      _notify();
      return null;
    } catch (e) {
      return apiErrorMessage(e);
    }
  }

  /// Add saved route
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

  /// Remove saved route
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

  /// Set notification pref
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

  /// Record trip
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

  /// Adjust stats
  void _adjustStats({int trips = 0, int savedRoutes = 0, int reviews = 0}) {
    final profile = _profile;
    if (profile == null) return;
    _profile = profile.copyWith(
      stats: profile.stats.copyWith(
        trips: profile.stats.trips + trips,
        savedRoutes: profile.stats.savedRoutes + savedRoutes,
        reviews: profile.stats.reviews + reviews,
      ),
    );
  }

  /// Notify profile
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Clean up resources
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
