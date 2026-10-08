import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import '../models/trip_plan.dart';

// Tawag sa backend POST /trip-plan (commuter only).
// I-pass ang Dio gikan sa buildDioClient() para ma-attach ang token.
class TripPlanService {
  TripPlanService(this._dio);

  static const Duration planTimeout = Duration(seconds: 70);

  final Dio _dio;

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
          'max_transfers': 2,
        },
      },
      // Kung wala pa ma-load ang road graph, ang backend mo-fetch pa sa
      // Overpass (hangtod 65s) — dili igo ang default 10s.
      options: Options(receiveTimeout: planTimeout),
    );

    return TripPlanResponse.fromJson(response.data as Map<String, dynamic>);
  }

  // GeoJSON order is [lng, lat] — dali ra mabali, double check
  static Map<String, dynamic> _point(LatLng point) => {
        'type': 'Point',
        'coordinates': [point.longitude, point.latitude],
      };
}
