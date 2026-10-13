// lib/services/alerts_service.dart
//
// Transit alerts for the commuter's Notifications screen.
// Signed-in commuters get /alerts/feed (with read state); guests get the
// public /alerts list, which has no read state.

import 'package:dio/dio.dart';

import '../models/commuter_alert.dart';

class AlertsService {
  AlertsService(this._dio);

  final Dio _dio;

  Future<List<CommuterAlert>> feed({required bool isGuest}) async {
    final response = await _dio.get(isGuest ? '/alerts' : '/alerts/feed');
    return (response.data as List<dynamic>)
        .map((item) => CommuterAlert.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String alertId) => _dio.post('/alerts/$alertId/read');

  Future<void> markAllRead() => _dio.post('/alerts/read-all');
}
