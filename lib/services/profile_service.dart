// lib/services/profile_service.dart
//
// The signed-in commuter's profile, saved routes, trips and notification
// choices (/users/me, /users/me/saved-routes, /users/me/trips,
// /users/me/settings).

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../models/commuter_profile.dart';
import '../models/ride_review.dart';

class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  Future<CommuterProfile> profile() async {
    final response = await _dio.get('/users/me');
    return CommuterProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CommuterProfile> updateName(String name) async {
    final response = await _dio.patch('/users/me', data: {'name': name});
    return CommuterProfile.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<SavedRoute>> savedRoutes() async {
    final response = await _dio.get('/users/me/saved-routes');
    return (response.data as List<dynamic>)
        .map((item) => SavedRoute.fromJson(item as Map<String, dynamic>))
        .toList();
  }

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

  Future<void> deleteSavedRoute(String id) => _dio.delete('/users/me/saved-routes/$id');

  /// Rates a ride: [vehicleId] null when the commuter didn't catch the plate.
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

  Future<List<RideReview>> myReviews() async {
    final response = await _dio.get('/reviews/mine', queryParameters: {'limit': 10});
    return [
      for (final item in response.data as List<dynamic>) RideReview.fromJson(item as Map<String, dynamic>),
    ];
  }

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

  Future<Map<NotificationPref, bool>> notificationPrefs() async {
    final response = await _dio.get('/users/me/settings');
    return NotificationPref.fromSettings(response.data as Map<String, dynamic>);
  }

  Future<void> setNotificationPref(NotificationPref pref, bool enabled) =>
      _dio.patch('/users/me/settings', data: {pref.apiKey: enabled});

  // GeoJSON order is [lng, lat].
  static Map<String, dynamic> _point(LatLng point) => {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      };
}
