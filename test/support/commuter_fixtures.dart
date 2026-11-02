// Sample notification / profile responses (same shape as the backend) and
// fake backends that answer by "METHOD /path".

import 'package:dio/dio.dart';

import 'fake_dio.dart';

Map<String, dynamic> noticeJson(
  String id, {
  String title = 'Route Suspended',
  String category = 'service_alert',
  String? severity = 'critical',
  bool isRead = false,
  List<String> routeCodes = const ['J01'],
  int minutesAgo = 2,
}) =>
    {
      'id': id,
      'category': category,
      'severity': category == 'service_alert' ? severity : null,
      'title': title,
      'message': '$title — details for commuters.',
      'company_name': 'Cebu City Transport Co.',
      'route_codes': routeCodes,
      'created_at': DateTime.now().toUtc().subtract(Duration(minutes: minutesAgo)).toIso8601String(),
      'is_read': isRead,
      'read_at': null,
    };

/// A mix of every kind: two service alerts, a schedule change, a promotion, and one read.
List<Map<String, dynamic>> sampleInbox() => [
      noticeJson('n1'),
      noticeJson('n2', title: 'Heavy Traffic Ahead', severity: 'warning', minutesAgo: 8),
      noticeJson('n3', title: 'New Stop Added', category: 'schedule_change', routeCodes: ['J03'], minutesAgo: 22),
      noticeJson('n4', title: 'Free Ride Friday', category: 'promotion', routeCodes: ['J01', 'J02'], minutesAgo: 30),
      noticeJson('n5', title: 'Road Reopened', severity: 'info', routeCodes: ['B04'], isRead: true, minutesAgo: 60),
    ];

/// A backend with [inbox] that filters by ?category= and pages with ?skip=&limit=,
/// like GET /notices/inbox; other requests are answered from [routes].
FakeAdapter noticesBackend(List<Map<String, dynamic>> inbox, {Map<String, Object?> routes = const {}}) {
  final rest = fakeBackend(routes);
  return FakeAdapter((options) async {
    final query = options.queryParameters;
    if (options.method == 'GET' && options.path == '/notices/inbox') {
      final category = query['category'];
      final kept = [for (final n in inbox) if (category == null || n['category'] == category) n];
      final skip = (query['skip'] as int?) ?? 0;
      final limit = (query['limit'] as int?) ?? 50;
      return jsonBody(kept.skip(skip).take(limit).toList());
    }
    if (options.method == 'GET' && options.path == '/notices/inbox/unread-count') {
      return jsonBody({'count': inbox.where((n) => n['is_read'] != true).length});
    }
    return rest.handler(options);
  });
}

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
