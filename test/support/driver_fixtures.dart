// Sample driver-portal responses (same shape as the backend) and a GPS
// session that records start/stop instead of using the device's location.

import 'package:smartcommute_app/services/websocket_service.dart';

Map<String, dynamic> vehicleJson({String id = 'v1', String plate = 'ABC 123', bool hasTracker = true}) => {
      'id': id,
      'plate_number': plate,
      'route_id': 'r1',
      'route_code': 'J02',
      'route_name': 'Talamban – Pier 1',
      'terminal_a': 'Talamban',
      'terminal_b': 'Pier 1 Terminal',
      'has_tracker': hasTracker,
    };

Map<String, dynamic> shiftJson({int crowd = 0, int passengers = 0, String vehicleId = 'v1'}) => {
      'id': 's1',
      'vehicle_id': vehicleId,
      'started_at': DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String(),
      'crowd_percent': crowd,
      'passengers': passengers,
    };

Map<String, dynamic> dashboardJson({
  List<Map<String, dynamic>>? vehicles,
  Map<String, dynamic>? shift,
  String dutyStatus = 'unavailable',
}) =>
    {
      'name': 'Juan Dela Cruz',
      'driver_code': 'DRV-001',
      'duty_status': dutyStatus,
      'vehicles': vehicles ?? [vehicleJson()],
      'shift': shift,
    };

Map<String, dynamic> summaryJson() => {
      'id': 's1',
      'started_at': '2026-10-12T00:30:00Z',
      'ended_at': '2026-10-12T01:50:04Z',
      'duration_seconds': 4804,
      'distance_km': 1.1,
      'trips': 1,
      'passengers': 15,
      'avg_crowd_percent': 60,
      'gps_coverage': 'full',
      'vehicle': vehicleJson(),
    };

class FakeGpsSession extends GpsIngestionSession {
  FakeGpsSession({this.startError}) : super(accessToken: () async => 'token');

  /// Thrown by start(), e.g. location permission denied.
  final Exception? startError;

  final List<String> started = [];
  int stops = 0;
  bool _on = false;

  @override
  bool get isActive => _on;

  @override
  Future<void> start(String vehicleId) async {
    if (startError != null) throw startError!;
    started.add(vehicleId);
    _on = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    _on = false;
    notifyListeners();
  }
}
