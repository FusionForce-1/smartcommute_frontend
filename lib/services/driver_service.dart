// lib/services/driver_service.dart
//
// The signed-in driver's dashboard and shift reports (/drivers/me), the
// reports they send their operator (/driver-reports), and the route line for
// their map (GET /routes/{id}).
// Shifts themselves are started and ended by the operator in the portal.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/driver_dashboard.dart';
import '../models/driver_report.dart';
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

  /// Route Status during a shift: On-Route / Delayed / Unavailable.
  Future<void> setRouteStatus(RouteStatus status) =>
      _dio.put('/drivers/me/shift/status', data: {'status': status.apiValue});

  /// Sends a report to the driver's operator. Resending with the same
  /// [requestId] (after a dropped connection) returns the original.
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

  /// The reports this driver sent, newest first; [since] / [until] narrow it to a period.
  Future<List<DriverReport>> sentReports({int limit = 50, DateTime? since, DateTime? until}) async {
    final response = await _dio.get('/driver-reports/sent', queryParameters: {
      'limit': limit,
      if (since != null) 'since': since.toUtc().toIso8601String(),
      if (until != null) 'until': until.toUtc().toIso8601String(),
    });
    return [for (final r in response.data as List) DriverReport.fromJson(r as Map<String, dynamic>)];
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
