import 'package:dio/dio.dart';

import '../models/fleet.dart';

/// Data for the operator dashboard home.
class FleetService {
  FleetService(this._dio);

  final Dio _dio;

  /// The logged-in operator's vehicles with live status.
  Future<List<FleetVehicle>> getFleet() async {
    final response = await _dio.get('/fleet');
    return (response.data as List<dynamic>)
        .map((item) => FleetVehicle.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Active routes, keyed by id.
  Future<Map<String, RouteSummary>> getRoutes() async {
    final response = await _dio.get('/routes');
    final routes = (response.data as List<dynamic>)
        .map((item) => RouteSummary.fromJson(item as Map<String, dynamic>));
    return {for (final r in routes) r.id: r};
  }

  /// Announcements currently visible to this operator, newest first.
  Future<List<Announcement>> getAnnouncements() async {
    final response = await _dio.get('/announcements');
    return (response.data as List<dynamic>)
        .map((item) => Announcement.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
