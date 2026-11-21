// Profile service
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../models/commuter_profile.dart';
import '../models/ride_review.dart';
import '../models/security_info.dart';

/// Profile service
class ProfileService {
  /// Create profile
  ProfileService(this._dio);

  final Dio _dio;

  /// Profile profile
  Future<CommuterProfile> profile() async {
    final response = await _dio.get('/users/me');
    return CommuterProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update name
  Future<CommuterProfile> updateName(String name) async {
    final response = await _dio.patch('/users/me', data: {'name': name});
    return CommuterProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Saved routes
  Future<List<SavedRoute>> savedRoutes() async {
    final response = await _dio.get('/users/me/saved-routes');
    return (response.data as List<dynamic>)
        .map((item) => SavedRoute.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Save route
  Future<SavedRoute> saveRoute({
    required String label,
    required String routeId,
    required String originName,
    required String destinationName,
    LatLng? origin,
    LatLng? destination,
  }) async {
    final response = await _dio.post('/users/me/saved-routes', data: {
      'label': label,
      'route_id': routeId,
      'origin_name': originName,
      'destination_name': destinationName,
      if (origin != null) 'origin': _point(origin),
      if (destination != null) 'destination': _point(destination),
    });
    return SavedRoute.fromJson(response.data as Map<String, dynamic>);
  }

  /// Delete saved route
  Future<void> deleteSavedRoute(String id) => _dio.delete('/users/me/saved-routes/$id');

  /// Submit review
  Future<RideReview> submitReview({
    required String routeId,
    String? vehicleId,
    required int rating,
    required List<String> tags,
    String? comment,
  }) async {
    final response = await _dio.post('/reviews', data: {
      'route_id': routeId,
      if (vehicleId != null) 'vehicle_id': vehicleId,
      'rating': rating,
      'tags': tags,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
    return RideReview.fromJson(response.data as Map<String, dynamic>);
  }

  /// My reviews
  Future<List<RideReview>> myReviews() async {
    final response = await _dio.get('/reviews/mine', queryParameters: {'limit': 10});
    return [
      for (final item in response.data as List<dynamic>) RideReview.fromJson(item as Map<String, dynamic>),
    ];
  }

  /// Send feedback
  Future<void> sendFeedback({required String category, required String message, String? routeId}) =>
      _dio.post('/feedback', data: {
        'category': category,
        'message': message,
        if (routeId != null) 'route_id': routeId,
      });

  /// Record trip
  Future<void> recordTrip({
    required List<String> routeIds,
    required String originName,
    required String destinationName,
    required double totalFare,
    required int totalEtaMin,
  }) {
    return _dio.post('/users/me/trips', data: {
      'route_ids': routeIds,
      'origin_name': originName,
      'destination_name': destinationName,
      'total_fare': totalFare,
      'total_eta_min': totalEtaMin,
    });
  }

  /// Notification prefs
  Future<Map<NotificationPref, bool>> notificationPrefs() async {
    final response = await _dio.get('/users/me/settings');
    return NotificationPref.fromSettings(response.data as Map<String, dynamic>);
  }

  /// Set notification pref
  Future<void> setNotificationPref(NotificationPref pref, bool enabled) =>
      _dio.patch('/users/me/settings', data: {pref.apiKey: enabled});


  /// Profile security
  Future<SecurityInfo> security() async {
    final response = await _dio.get('/users/me/security');
    return SecurityInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Change password
  Future<void> changePassword({required String current, required String next}) =>
      _dio.post('/users/me/password', data: {
        'current_password': current,
        'new_password': next,
      });

  /// Start two factor
  Future<String> startTwoFactor() async {
    final response = await _dio.post('/users/me/two-factor/start');
    return (response.data as Map<String, dynamic>)['email'] as String? ?? 'your email';
  }

  /// Confirm two factor
  Future<void> confirmTwoFactor(String otp) =>
      _dio.post('/users/me/two-factor/confirm', data: {'otp': otp});

  /// Turn off two factor
  Future<void> turnOffTwoFactor({String? password, String? otp}) =>
      _dio.patch('/users/me/settings', data: {
        'two_factor_enabled': false,
        if (password != null) 'current_password': password,
        if (otp != null) 'otp': otp,
      });

  /// Email turn-off code
  Future<String> sendTwoFactorOffCode() async {
    final response = await _dio.post('/users/me/two-factor/disable-code');
    return (response.data as Map<String, dynamic>)['email'] as String? ?? 'your email';
  }

  /// Accept terms
  Future<SecurityInfo> acceptTerms() async {
    final response = await _dio.post('/users/me/accept-terms');
    return SecurityInfo.fromJson(response.data as Map<String, dynamic>);
  }

  /// Profile point
  static Map<String, dynamic> _point(LatLng point) => {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      };
}
