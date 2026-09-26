import 'package:dio/dio.dart';

import '../models/transport_stop.dart';

class StopsService {
  StopsService(this._dio);

  final Dio _dio;

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