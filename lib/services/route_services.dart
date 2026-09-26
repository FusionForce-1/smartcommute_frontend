import 'package:dio/dio.dart';

import '../models/transport_model.dart';

class RoutesService {
  RoutesService(this._dio);

  final Dio _dio;

  Future<List<TransportRoute>> getRoutes() async {
    final response = await _dio.get('/routes');

    final data = response.data as List<dynamic>;

    return data
        .map(
          (json) => TransportRoute.fromJson(
            json as Map<String, dynamic>,
          ),
        )
        .toList();
  }
}