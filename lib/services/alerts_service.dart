import 'package:dio/dio.dart';

import '../models/transit_alert.dart';

/// Transit alerts the operator publishes, and their own profile.
class AlertsService {
  AlertsService(this._dio);

  final Dio _dio;

  /// The operator's alerts: unresolved first, then newest first.
  Future<List<TransitAlert>> getMyAlerts() async {
    final response = await _dio.get('/alerts/mine');
    return (response.data as List<dynamic>)
        .map((item) => TransitAlert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Publishes an alert to commuters and drivers.
  Future<TransitAlert> publish(NewAlert alert) async {
    final response = await _dio.post('/alerts', data: alert.toJson());
    return TransitAlert.fromJson(response.data as Map<String, dynamic>);
  }

  /// Marks an alert as resolved, or reopens it.
  Future<TransitAlert> setResolved(String alertId, bool resolved) async {
    final response = await _dio.patch(
      '/alerts/$alertId/resolved',
      data: {'is_resolved': resolved},
    );
    return TransitAlert.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> deleteAlert(String alertId) async {
    await _dio.delete('/alerts/$alertId');
  }

  /// Throws a 404 [DioException] when the operator has no company profile yet.
  Future<OperatorProfile> getProfile() async {
    final response = await _dio.get('/operators/me');
    return OperatorProfile.fromJson(response.data as Map<String, dynamic>);
  }

  /// Creates the operator's company profile (POST /operators).
  Future<void> createProfile({
    required String companyName,
    String? franchiseNumber,
    String? contactNumber,
  }) async {
    await _dio.post('/operators', data: {
      'company_name': companyName,
      'franchise_number': franchiseNumber,
      'contact_number': contactNumber,
    });
  }
}
