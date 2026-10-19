// lib/models/ride_review.dart
//
// A commuter's rating of a jeepney ride (POST /reviews, GET /reviews/mine).
// The backend credits it to the jeep's assigned driver; the operator sees
// it on their Reports page, never who wrote it.

import 'vehicle_live_update.dart' show parseServerTime;

/// Quick tags; the backend accepts exactly these keys.
class ReviewTag {
  const ReviewTag(this.key, this.label, {required this.positive});

  final String key;
  final String label;
  final bool positive;

  static const all = [
    ReviewTag('safe_driving', 'Safe driving', positive: true),
    ReviewTag('friendly', 'Friendly driver', positive: true),
    ReviewTag('clean', 'Clean jeep', positive: true),
    ReviewTag('on_time', 'On time', positive: true),
    ReviewTag('honest_fare', 'Honest fare', positive: true),
    ReviewTag('reckless_driving', 'Reckless driving', positive: false),
    ReviewTag('rude', 'Rude', positive: false),
    ReviewTag('overcharging', 'Overcharging', positive: false),
    ReviewTag('overloading', 'Overloading', positive: false),
    ReviewTag('late', 'Long wait / late', positive: false),
    ReviewTag('dirty', 'Dirty jeep', positive: false),
  ];

  static String labelOf(String key) =>
      all.firstWhere((t) => t.key == key, orElse: () => ReviewTag(key, key.replaceAll('_', ' '), positive: true)).label;
}

class RideReview {
  const RideReview({
    required this.id,
    required this.routeId,
    required this.rating,
    required this.tags,
    required this.createdAt,
    this.routeCode,
    this.plateNumber,
    this.comment,
  });

  final String id;
  final String routeId;
  final String? routeCode;
  final String? plateNumber;
  final int rating;
  final List<String> tags;
  final String? comment;
  final DateTime createdAt;

  factory RideReview.fromJson(Map<String, dynamic> json) => RideReview(
        id: json['id'] as String,
        routeId: json['route_id'] as String,
        routeCode: json['route_code'] as String?,
        plateNumber: json['plate_number'] as String?,
        rating: json['rating'] as int,
        tags: [for (final t in json['tags'] as List? ?? const []) t as String],
        comment: json['comment'] as String?,
        createdAt: parseServerTime(json['created_at']) ?? DateTime.now(),
      );
}
