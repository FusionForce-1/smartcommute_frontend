// Every class here follows the same pattern:
//   - a plain Dart class with typed fields
//   - a `fromJson` factory that converts the raw Map<String,dynamic>
//     Dio gives you back into that typed object
// ApiService methods return these typed objects instead of raw JSON,
// so the rest of your app never has to write response['field'] and
// risk typos or null-safety crashes.

import 'vehicle_live_update.dart' show parseServerTime;

// ---------------------------------------------------------------
// AUTH
// ---------------------------------------------------------------

class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String role;
  final int expiresIn;

  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.role,
    required this.expiresIn,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
        tokenType: json['token_type'],
        role: json['role'],
        expiresIn: json['expires_in'],
      );
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final bool isVerified;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.isVerified,
  });

  String get fullName => name;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        email: json['email'],
        name: json['name'] ?? '',
        role: json['role'],
        isActive: json['is_active'],
        isVerified: json['is_verified'] ?? false,
      );
}

// Used when SENDING a registration request — not parsed from JSON,
// so it needs toJson() instead of fromJson().
class UserCreate {
  final String email;
  final String password;
  final String name;
  final String? role;

  /// The User Agreement / Privacy Policy box — the backend requires it.
  final bool acceptedTerms;

  UserCreate({
    required this.email,
    required this.password,
    required this.name,
    this.role,
    this.acceptedTerms = false,
  });

  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'name': name,
        if (role != null) 'role': role,
        'accepted_terms': acceptedTerms,
      };
}

class UserUpdate {
  final String? name;
  final String? role;
  final bool? isActive;

  UserUpdate({this.name, this.role, this.isActive});

  // Only includes fields that were actually set — PATCH requests
  // should never send null for a field you didn't mean to change.
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (role != null) map['role'] = role;
    if (isActive != null) map['is_active'] = isActive;
    return map;
  }
}

// ---------------------------------------------------------------
// GEOJSON (shared shape used by routes, stops, trips)
// ---------------------------------------------------------------

class GeoJSONPoint {
  final double lat;
  final double lng;

  GeoJSONPoint({required this.lat, required this.lng});

  factory GeoJSONPoint.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List;
    return GeoJSONPoint(lat: coords[1].toDouble(), lng: coords[0].toDouble());
  }

  // GeoJSON order is [lng, lat] — easy to get backwards, double check this
  Map<String, dynamic> toJson() => {
        'type': 'Point',
        'coordinates': [lng, lat],
      };
}

// ---------------------------------------------------------------
// ROUTES / STOPS / VEHICLES
// ---------------------------------------------------------------

class StopModel {
  final String id;
  final String name;
  final int sequence;
  final GeoJSONPoint location;
  final String? landmark;

  StopModel({
    required this.id,
    required this.name,
    required this.sequence,
    required this.location,
    this.landmark,
  });

  factory StopModel.fromJson(Map<String, dynamic> json) => StopModel(
        id: json['id'],
        name: json['name'],
        sequence: json['sequence'],
        location: GeoJSONPoint.fromJson(json['location']),
        landmark: json['landmark'],
      );
}

class FareMatrix {
  final double base;
  final double perKm;

  FareMatrix({required this.base, required this.perKm});

  factory FareMatrix.fromJson(Map<String, dynamic> json) => FareMatrix(
        base: json['base'].toDouble(),
        perKm: json['per_km'].toDouble(),
      );
}

class RouteModel {
  final String id;
  final String name;
  final String code;
  final List<StopModel> stops;
  final FareMatrix fareMatrix;
  final bool isActive;

  RouteModel({
    required this.id,
    required this.name,
    required this.code,
    required this.stops,
    required this.fareMatrix,
    required this.isActive,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        id: json['id'],
        name: json['name'],
        code: json['code'],
        stops: (json['stops'] as List)
            .map((s) => StopModel.fromJson(s))
            .toList(),
        fareMatrix: FareMatrix.fromJson(json['fare_matrix']),
        isActive: json['is_active'],
      );
}

class VehicleModel {
  final String id;
  final String plateNumber;
  final String routeId;
  final String status;
  final String? crowdLevel;
  final GPSPositionModel? lastPosition;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    required this.status,
    this.crowdLevel,
    this.lastPosition,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) => VehicleModel(
        id: json['id'],
        plateNumber: json['plate_number'],
        routeId: json['route_id'],
        status: json['status'],
        crowdLevel: json['crowd_level'],
        lastPosition: json['last_position'] != null
            ? GPSPositionModel.fromJson(json['last_position'], vehicleId: json['id'])
            : null,
      );
}

class GPSPositionModel {
  final String vehicleId;
  final double lat;
  final double lng;
  final double? speed; // km/h
  final double? heading; // degrees from north
  final DateTime? timestamp; // device fix time (UTC)

  GPSPositionModel({
    required this.vehicleId,
    required this.lat,
    required this.lng,
    this.speed,
    this.heading,
    this.timestamp,
  });

  // The backend sends positions in two shapes:
  //   GET /vehicles/{id}/position -> {"location": GeoJSON Point, "timestamp", ...}
  //   vehicle.last_position       -> {"lat", "lng", "timestamp"} (no vehicle_id)
  // so accept both instead of assuming flat lat/lng.
  factory GPSPositionModel.fromJson(Map<String, dynamic> json, {String? vehicleId}) {
    final double lat;
    final double lng;
    if (json['location'] != null) {
      final point = GeoJSONPoint.fromJson(json['location']);
      lat = point.lat;
      lng = point.lng;
    } else {
      lat = (json['lat'] as num).toDouble();
      lng = (json['lng'] as num).toDouble();
    }
    return GPSPositionModel(
      vehicleId: json['vehicle_id'] ?? vehicleId ?? '',
      lat: lat,
      lng: lng,
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: parseServerTime(json['timestamp'] ?? json['ts']),
    );
  }
}

// ---------------------------------------------------------------
// ROUTE STATUS (driver/operator updates)
// ---------------------------------------------------------------

class RouteStatusUpdate {
  final String routeId;
  final String status; // "active" | "suspended" | "congested"
  final String? reason;

  RouteStatusUpdate({required this.routeId, required this.status, this.reason});

  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        'status': status,
        if (reason != null) 'reason': reason,
      };
}

// ---------------------------------------------------------------
// TRIP PLANNING
// ---------------------------------------------------------------

class TripPrefs {
  final String minimize; // "time" | "fare" | "transfers"
  final int maxTransfers;

  TripPrefs({this.minimize = 'time', this.maxTransfers = 2});

  Map<String, dynamic> toJson() => {
        'minimize': minimize,
        'max_transfers': maxTransfers,
      };
}

class TripPlanRequest {
  final GeoJSONPoint origin;
  final GeoJSONPoint destination;
  final DateTime preferredArrival;
  final TripPrefs preferences;

  TripPlanRequest({
    required this.origin,
    required this.destination,
    required this.preferredArrival,
    required this.preferences,
  });

  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'preferred_arrival': preferredArrival.toIso8601String(),
        'preferences': preferences.toJson(),
      };
}

class RouteLeg {
  final String routeId;
  final String routeName;
  final StopModel boardStop;
  final StopModel alightStop;
  final int etaMin;
  final double fare;

  RouteLeg({
    required this.routeId,
    required this.routeName,
    required this.boardStop,
    required this.alightStop,
    required this.etaMin,
    required this.fare,
  });

  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
        routeId: json['route_id'],
        routeName: json['route_name'],
        boardStop: StopModel.fromJson(json['board_stop']),
        alightStop: StopModel.fromJson(json['alight_stop']),
        etaMin: json['eta_min'],
        fare: json['fare'].toDouble(),
      );
}

class RouteOption {
  final int rank;
  final List<RouteLeg> legs;
  final int totalEtaMin;
  final double totalFare;
  final int transfers;

  RouteOption({
    required this.rank,
    required this.legs,
    required this.totalEtaMin,
    required this.totalFare,
    required this.transfers,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        rank: json['rank'],
        legs: (json['legs'] as List).map((l) => RouteLeg.fromJson(l)).toList(),
        totalEtaMin: json['total_eta_min'],
        totalFare: json['total_fare'].toDouble(),
        transfers: json['transfers'],
      );
}

class TripPlanResponse {
  final List<RouteOption> options;
  final DateTime generatedAt;

  TripPlanResponse({required this.options, required this.generatedAt});

  factory TripPlanResponse.fromJson(Map<String, dynamic> json) =>
      TripPlanResponse(
        options: (json['options'] as List)
            .map((o) => RouteOption.fromJson(o))
            .toList(),
        generatedAt: DateTime.parse(json['generated_at']),
      );
}

// ---------------------------------------------------------------
// FEEDBACK
// ---------------------------------------------------------------

class FeedbackCreate {
  final String routeId;
  final String message;
  final String category; // delay | overcrowding | route_issue | driver_behavior | other
  final GeoJSONPoint? location;

  FeedbackCreate({
    required this.routeId,
    required this.message,
    required this.category,
    this.location,
  });

  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        'message': message,
        'category': category,
        if (location != null) 'location': location!.toJson(),
      };
}

class FeedbackResponse {
  final String id;
  final String routeId;
  final String message;
  final String category;
  final String status;

  FeedbackResponse({
    required this.id,
    required this.routeId,
    required this.message,
    required this.category,
    required this.status,
  });

  factory FeedbackResponse.fromJson(Map<String, dynamic> json) =>
      FeedbackResponse(
        id: json['id'],
        routeId: json['route_id'],
        message: json['message'],
        category: json['category'],
        status: json['status'],
      );
}

// ---------------------------------------------------------------
// ANNOUNCEMENTS
// ---------------------------------------------------------------

class Announcement {
  final String id;
  final String title;
  final String message;
  final String? targetRole;
  final DateTime expiresAt;

  Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.targetRole,
    required this.expiresAt,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'],
        title: json['title'],
        message: json['message'],
        targetRole: json['target_role'],
        expiresAt: DateTime.parse(json['expires_at']),
      );
}