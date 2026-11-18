// Driver service
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/driver_dashboard.dart';
import '../models/driver_report.dart';
import '../models/transport_model.dart';

/// Driver service
class DriverService {
  /// Create driver
  DriverService(this._dio, {FlutterSecureStorage storage = const FlutterSecureStorage()})
      : _storage = storage;

  final Dio _dio;
  final FlutterSecureStorage _storage;

  /// Driver dashboard
  Future<DriverDashboardData> dashboard() async {
    final response = await _dio.get('/drivers/me');
    return DriverDashboardData.fromJson(response.data as Map<String, dynamic>);
  }

  /// Report crowd
  Future<void> reportCrowd(int percent) =>
      _dio.put('/drivers/me/shift/crowd', data: {'percent': percent});

  /// Change passengers
  Future<int> changePassengers(int change) async {
    final response = await _dio.post('/drivers/me/shift/passengers', data: {'change': change});
    return (response.data['passengers'] as num).toInt();
  }

  /// Set route status
  Future<void> setRouteStatus(RouteStatus status) =>
      _dio.put('/drivers/me/shift/status', data: {'status': status.apiValue});

  /// Send report
  Future<DriverReport> sendReport({
    required DriverReportCategory category,
    String? note,
    required String requestId,
  }) async {
    final response = await _dio.post('/driver-reports', data: {
      'category': category.apiValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      'client_request_id': requestId,
    });
    return DriverReport.fromJson(response.data as Map<String, dynamic>);
  }

  /// Sent reports
  Future<List<DriverReport>> sentReports({int limit = 50, DateTime? since, DateTime? until}) async {
    final response = await _dio.get('/driver-reports/sent', queryParameters: {
      'limit': limit,
      if (since != null) 'since': since.toUtc().toIso8601String(),
      if (until != null) 'until': until.toUtc().toIso8601String(),
    });
    return [for (final r in response.data as List) DriverReport.fromJson(r as Map<String, dynamic>)];
  }

  /// Driver route
  Future<TransportRoute> route(String routeId) async {
    final response = await _dio.get('/routes/$routeId');
    return TransportRoute.fromJson(response.data as Map<String, dynamic>);
  }

  /// Fresh access token
  Future<String?> freshAccessToken() async {
    await _dio.get('/drivers/me');
    return _storage.read(key: 'access_token');
  }
}
