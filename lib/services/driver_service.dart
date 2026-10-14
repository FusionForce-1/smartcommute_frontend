// lib/services/driver_service.dart
//
// The signed-in driver's dashboard and shift (/drivers/me), plus the
// route line for their map (GET /routes/{id}).

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

  Future<DriverShift> startShift(String vehicleId) async {
    final response = await _dio.post('/drivers/me/shift', data: {'vehicle_id': vehicleId});
    return DriverShift.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> setDutyStatus(DutyStatus status) =>
      _dio.put('/drivers/me/status', data: {'status': status.apiValue});

  Future<void> reportCrowd(int percent) =>
      _dio.put('/drivers/me/shift/crowd', data: {'percent': percent});

  /// +1 when a passenger boards, -1 to undo. Returns the new count.
  Future<int> changePassengers(int change) async {
    final response = await _dio.post('/drivers/me/shift/passengers', data: {'change': change});
    return (response.data['passengers'] as num).toInt();
  }

  Future<ShiftSummary> endShift() async {
    final response = await _dio.post('/drivers/me/shift/end');
    return ShiftSummary.fromJson(response.data as Map<String, dynamic>);
  }

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
