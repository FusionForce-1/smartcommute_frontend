import 'package:dio/dio.dart';

import '../models/operator_route.dart';
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

  /// The operator's routes, active or not, with stop and vehicle counts.
  Future<List<OperatorRoute>> getMyRoutes() async {
    final response = await _dio.get('/routes/mine');
    return (response.data as List<dynamic>)
        .map((item) => OperatorRoute.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Creates an inactive route. Returns the new route's id.
  Future<String> createRoute(NewRoute route) async {
    final response = await _dio.post('/routes', data: route.toJson());
    return (response.data as Map<String, dynamic>)['id'] as String;
  }

  /// Activates a route, or pauses it so commuters no longer see it.
  Future<void> setActive(String routeId, bool isActive) async {
    await _dio.patch('/routes/$routeId/active', data: {'is_active': isActive});
  }

  Future<void> deleteRoute(String routeId) async {
    await _dio.delete('/routes/$routeId');
  }

  /// The operator's company name, shown in the page header.
  Future<String?> getCompanyName() async {
    final response = await _dio.get('/operators/me');
    return (response.data as Map<String, dynamic>)['company_name'] as String?;
  }
}
