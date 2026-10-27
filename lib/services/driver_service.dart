// lib/services/driver_service.dart
//
// The signed-in driver's dashboard and shift reports (/drivers/me), their
// updates (/notifications), and the route line for their map (GET /routes/{id}).
// Shifts themselves are started and ended by the operator in the portal.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/driver_dashboard.dart';
import '../models/transport_model.dart';

class DriverService {
  DriverService(this._dio, {FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<DriverDashboardData> dashboard() async {
    final response = await _dio.get('/drivers/me');
    return DriverDashboardData.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> reportCrowd(int percent) =>
      _dio.put('/drivers/me/shift/crowd', data: {'percent': percent});

  /// +1 when a passenger boards, -1 to undo. Returns the new count.
  Future<int> changePassengers(int change) async {
    final response = await _dio.post('/drivers/me/shift/passengers', data: {'change': change});
    return (response.data['passengers'] as num).toInt();
  }

  /// The newest notifications first.
  Future<List<DriverUpdate>> updates({int limit = 20}) async {
    final response = await _dio.get('/notifications', queryParameters: {'limit': limit});
    return [for (final n in response.data as List) DriverUpdate.fromJson(n as Map<String, dynamic>)];
  }

  Future<void> markUpdatesRead() => _dio.post('/notifications/read-all');

  /// The route's line and stops; throws (404) if it has no map yet.
  Future<TransportRoute> route(String routeId) async {
    final response = await _dio.get('/routes/$routeId');
    return TransportRoute.fromJson(response.data as Map<String, dynamic>);
  }

  /// An access token for the GPS socket. Any signed-in request refreshes an
  /// expired token (see DioInterceptor), so the stored one is current after it.
  Future<String?> freshAccessToken() async {
    await _dio.get('/drivers/me');
    return _storage.read(key: 'access_token');
  }
}
