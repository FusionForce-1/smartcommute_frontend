// Trip plan service
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_plan.dart';

/// Trip plan service
class TripPlanService {
  /// Create trip plan
  TripPlanService(this._dio);

  static const Duration planTimeout = Duration(seconds: 70);

  final Dio _dio;

  /// Plan trip
  Future<TripPlanResponse> planTrip({
    required LatLng origin,
    required LatLng destination,
    TripPreference preference = TripPreference.time,
  }) async {
    final response = await _dio.post(
      '/trip-plan',
      data: {
        'origin': _point(origin),
        'destination': _point(destination),
        'preferences': {
          'minimize': preference.apiValue,
          'max_transfers': 1,
        },
      },
      options: Options(receiveTimeout: planTimeout),
    );

    return TripPlanResponse.fromJson(response.data as Map<String, dynamic>);
  }

  /// Trip plan point
  static Map<String, dynamic> _point(LatLng point) => {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      };
}
