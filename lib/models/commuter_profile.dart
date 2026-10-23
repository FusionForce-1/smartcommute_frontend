// lib/models/commuter_profile.dart
//
// The signed-in commuter's profile (GET /users/me), saved routes
// (/users/me/saved-routes) and notification choices (/users/me/settings).

import 'package:latlong2/latlong.dart';

class ProfileStats {
  const ProfileStats({this.trips = 0, this.savedRoutes = 0, this.reviews = 0});

  final int trips;
  final int savedRoutes;
  final int reviews;

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
        trips: json['trips'] as int? ?? 0,
        savedRoutes: json['saved_routes'] as int? ?? 0,
        reviews: json['reviews'] as int? ?? 0,
      );

  ProfileStats copyWith({int? trips, int? savedRoutes, int? reviews}) => ProfileStats(
        trips: trips ?? this.trips,
        savedRoutes: savedRoutes ?? this.savedRoutes,
        reviews: reviews ?? this.reviews,
      );
}

class CommuterProfile {
  const CommuterProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.stats,
    this.email,
  });

  final String id;
  final String name;
  final String? email;
  final String role;
  final ProfileStats stats;

  /// First letters of the first two words: "Juan Dela Cruz" → "JD".
  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    if (words.isEmpty) return '?';
    return words.take(2).map((w) => w[0]).join().toUpperCase();
  }

  factory CommuterProfile.fromJson(Map<String, dynamic> json) => CommuterProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        role: json['role'] as String,
        stats: ProfileStats.fromJson(json['stats'] as Map<String, dynamic>? ?? const {}),
      );

  CommuterProfile copyWith({String? name, ProfileStats? stats}) => CommuterProfile(
        id: id,
        name: name ?? this.name,
        email: email,
        role: role,
        stats: stats ?? this.stats,
      );
}

class SavedRoute {
  const SavedRoute({
    required this.id,
    required this.label,
    required this.routeId,
    required this.originName,
    required this.destinationName,
    this.routeCode,
    this.origin,
    this.destination,
  });

  final String id;
  final String label;
  final String routeId;
  final String? routeCode;
  final String originName;
  final String destinationName;
  final LatLng? origin;
  final LatLng? destination;

  factory SavedRoute.fromJson(Map<String, dynamic> json) => SavedRoute(
        id: json['id'] as String,
        label: json['label'] as String,
        routeId: json['route_id'] as String,
        routeCode: json['route_code'] as String?,
        originName: json['origin_name'] as String,
        destinationName: json['destination_name'] as String,
        origin: _point(json['origin']),
        destination: _point(json['destination']),
      );

  static LatLng? _point(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final coordinates = json['coordinates'] as List<dynamic>;
    return LatLng((coordinates[1] as num).toDouble(), (coordinates[0] as num).toDouble());
  }
}

/// Which commuter notifications to receive.
enum NotificationPref {
  routeAlerts('route_alerts', 'Route Alerts', 'Delays, suspensions, incidents'),
  scheduleUpdates('schedule_updates', 'Schedule Updates', 'New stops, time changes'),
  promotions('promotions', 'Promotions', 'Fare discounts, special offers');

  const NotificationPref(this.apiKey, this.title, this.subtitle);

  final String apiKey;
  final String title;
  final String subtitle;

  /// Values from GET /users/me/settings, with the backend's defaults.
  static Map<NotificationPref, bool> fromSettings(Map<String, dynamic> json) => {
        for (final pref in values) pref: json[pref.apiKey] as bool? ?? pref != promotions,
      };
}
