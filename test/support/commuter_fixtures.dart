// Sample alert / profile responses (same shape as the backend) and a fake
// backend that answers by "METHOD /path".

import 'package:dio/dio.dart';

import 'fake_dio.dart';

Map<String, dynamic> alertJson(
  String id, {
  String title = 'Route Suspended',
  String severity = 'critical',
  bool isResolved = false,
  bool isRead = false,
  String? routeCode = 'J01',
  int minutesAgo = 2,
}) =>
    {
      'id': id,
      'title': title,
      'message': '$title — details for commuters.',
      'severity': severity,
      'route_id': routeCode == null ? null : 'r-$routeCode',
      'route_code': routeCode,
      'operator_id': 'op1',
      'company_name': 'Cebu City Transport Co.',
      'is_resolved': isResolved,
      'created_at': DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      'resolved_at': isResolved ? DateTime.now().toUtc().toIso8601String() : null,
      'is_read': isRead,
    };

/// Same mix as the design: critical, warning, info, resolved, and one read.
List<Map<String, dynamic>> sampleFeed() => [
      alertJson('a1'),
      alertJson('a2', title: 'Heavy Traffic Ahead', severity: 'warning', minutesAgo: 8),
      alertJson('a3', title: 'Schedule Change', severity: 'info', routeCode: 'J03', minutesAgo: 22),
      alertJson('a4', title: 'Incident Cleared', severity: 'warning', isResolved: true, minutesAgo: 30),
      alertJson('a5', title: 'New Stop Added', severity: 'info', routeCode: 'B04', isRead: true, minutesAgo: 60),
    ];

Map<String, dynamic> profileJson({int trips = 47, int savedRoutes = 1, int reviews = 12}) => {
      'id': 'u1',
      'name': 'Juan Dela Cruz',
      'email': 'juan.delacruz@gmail.com',
      'role': 'commuter',
      'stats': {'trips': trips, 'saved_routes': savedRoutes, 'reviews': reviews},
    };

Map<String, dynamic> savedRouteJson(String id, {String label = 'Home → Office'}) => {
      'id': id,
      'label': label,
      'route_id': 'r1',
      'route_code': 'J01',
      'origin_name': 'Talamban',
      'destination_name': 'Ayala Center Cebu',
      'origin': {'type': 'Point', 'coordinates': [123.91, 10.37]},
      'destination': {'type': 'Point', 'coordinates': [123.905, 10.318]},
      'created_at': '2026-10-12T08:00:00',
    };

Map<String, dynamic> settingsJson() => {
      'email_notifications': true,
      'two_factor_enabled': false,
      'language': 'en-PH',
      'route_alerts': true,
      'schedule_updates': true,
      'promotions': false,
    };

/// Answers each request from [routes] ("GET /users/me" → body, or a status
/// code as an int for an error). Unknown requests get a 404.
FakeAdapter fakeBackend(Map<String, Object?> routes) {
  return FakeAdapter((options) async {
    final key = '${options.method} ${options.path}';
    if (!routes.containsKey(key)) return jsonBody({'detail': 'Not found'}, status: 404);
    final answer = routes[key];
    if (answer is int) return jsonBody({'detail': 'Request failed'}, status: answer);
    return jsonBody(answer ?? const {}, status: options.method == 'POST' ? 201 : 200);
  });
}

/// The requests the fake backend saw, as "METHOD /path".
List<String> calls(FakeAdapter adapter) =>
    [for (final RequestOptions r in adapter.requests) '${r.method} ${r.path}'];
