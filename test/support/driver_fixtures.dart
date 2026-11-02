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

Map<String, dynamic> shiftJson({
  String id = 's1',
  int crowd = 0,
  int passengers = 0,
  String vehicleId = 'v1',
  double distanceKm = 0,
}) =>
    {
      'id': id,
      'vehicle_id': vehicleId,
      'started_at': DateTime.now().toUtc().subtract(const Duration(minutes: 5)).toIso8601String(),
      'crowd_percent': crowd,
      'passengers': passengers,
      'distance_km': distanceKm,
    };

Map<String, dynamic> dashboardJson({
  List<Map<String, dynamic>>? vehicles,
  Map<String, dynamic>? shift,
  String? dutyStatus,
  Map<String, dynamic>? recentRoute,
}) =>
    {
      'name': 'Juan Dela Cruz',
      'driver_code': 'DRV-001',
      'email': 'juan.delacruz@smartcommute.ph',
      'duty_status': dutyStatus ?? (shift == null ? 'unavailable' : 'on_route'),
      'vehicles': vehicles ?? [vehicleJson()],
      'shift': shift,
      'operator': {'company_name': 'Cebu Transit Co', 'owner_name': 'John'},
      'recent_route': recentRoute,
    };

Map<String, dynamic> reportJson({
  String id = 'r1',
  String category = 'breakdown',
  String? note = 'Flat tyre near Ayala',
  Map<String, dynamic>? context,
}) =>
    {
      'id': id,
      'category': category,
      'note': note,
      'context': context,
      'created_at': DateTime.now().toUtc().subtract(const Duration(minutes: 2)).toIso8601String(),
    };

/// The shift details the backend attaches to a report sent during a shift.
Map<String, dynamic> reportContextJson({bool located = true}) => {
      'shift_id': 's1',
      'vehicle_id': 'v1',
      'plate_number': 'ABC 123',
      'route_id': 'r1',
      'route_code': 'J02',
      'lat': located ? 10.33 : null,
      'lng': located ? 123.9 : null,
      'located_at': located ? DateTime.now().toUtc().toIso8601String() : null,
    };

class FakeGpsSession extends GpsIngestionSession {
  FakeGpsSession({this.startError}) : super(accessToken: () async => 'token');

  /// Thrown by start(), e.g. location permission denied.
  Exception? startError;

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
