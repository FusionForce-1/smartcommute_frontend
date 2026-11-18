// Stops services
import 'package:dio/dio.dart';

import '../models/transport_stop.dart';

/// Stops service
class StopsService {
  /// Create stops
  StopsService(this._dio);

  final Dio _dio;

  /// Get stops
  Future<List<TransportStop>> getStops() async {
    final response = await _dio.get('/stops');

    final data = response.data as List<dynamic>;

    return data
        .map(
          (json) => TransportStop.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}