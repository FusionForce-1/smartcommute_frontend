// Models model
import 'vehicle_live_update.dart' show parseServerTime;


/// Token response
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String role;
  final int expiresIn;

  /// Create token response
  TokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.role,
    required this.expiresIn,
  });

  /// Parse from JSON
  factory TokenResponse.fromJson(Map<String, dynamic> json) => TokenResponse(
        accessToken: json['access_token'],
        refreshToken: json['refresh_token'],
        tokenType: json['token_type'],
        role: json['role'],
        expiresIn: json['expires_in'],
      );
}

/// User model
class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final bool isVerified;

  /// Create user
  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.isVerified,
  });

  String get fullName => name;

  /// Parse from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        email: json['email'],
        name: json['name'] ?? '',
        role: json['role'],
        isActive: json['is_active'],
        isVerified: json['is_verified'] ?? false,
      );
}

/// User create
class UserCreate {
  final String email;
  final String password;
  final String name;
  final String? role;

  final bool acceptedTerms;

  /// Create user create
  UserCreate({
    required this.email,
    required this.password,
    required this.name,
    this.role,
    this.acceptedTerms = false,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'name': name,
        if (role != null) 'role': role,
        'accepted_terms': acceptedTerms,
      };
}

/// User update
class UserUpdate {
  final String? name;
  final String? role;
  final bool? isActive;

  /// Create user update
  UserUpdate({this.name, this.role, this.isActive});

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (name != null) map['name'] = name;
    if (role != null) map['role'] = role;
    if (isActive != null) map['is_active'] = isActive;
    return map;
  }
}


/// GeoJSON point
class GeoJSONPoint {
  final double lat;
  final double lng;

  /// Create GeoJSON point
  GeoJSONPoint({required this.lat, required this.lng});

  /// Parse from JSON
  factory GeoJSONPoint.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List;
    return GeoJSONPoint(lat: coords[1].toDouble(), lng: coords[0].toDouble());
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'type': 'Point',
        'coordinates': [lng, lat],
      };
}


/// Stop model
class StopModel {
  final String id;
  final String name;
  final int sequence;
  final GeoJSONPoint location;
  final String? landmark;

  /// Create stop
  StopModel({
    required this.id,
    required this.name,
    required this.sequence,
    required this.location,
    this.landmark,
  });

  /// Parse from JSON
  factory StopModel.fromJson(Map<String, dynamic> json) => StopModel(
        id: json['id'],
        name: json['name'],
        sequence: json['sequence'],
        location: GeoJSONPoint.fromJson(json['location']),
        landmark: json['landmark'],
      );
}

/// fare matrix
class FareMatrix {
  final double base;
  final double perKm;

  /// Create fare matrix
  FareMatrix({required this.base, required this.perKm});

  /// Parse from JSON
  factory FareMatrix.fromJson(Map<String, dynamic> json) => FareMatrix(
        base: json['base'].toDouble(),
        perKm: json['per_km'].toDouble(),
      );
}

/// Route model
class RouteModel {
  final String id;
  final String name;
  final String code;
  final List<StopModel> stops;
  final FareMatrix fareMatrix;
  final bool isActive;

  /// Create route
  RouteModel({
    required this.id,
    required this.name,
    required this.code,
    required this.stops,
    required this.fareMatrix,
    required this.isActive,
  });

  /// Parse from JSON
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

/// Vehicle model
class VehicleModel {
  final String id;
  final String plateNumber;
  final String routeId;
  final String status;
  final String? crowdLevel;
  final GPSPositionModel? lastPosition;

  /// Create vehicle
  VehicleModel({
    required this.id,
    required this.plateNumber,
    required this.routeId,
    required this.status,
    this.crowdLevel,
    this.lastPosition,
  });

  /// Parse from JSON
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

/// GPS position model
class GPSPositionModel {
  final String vehicleId;
  final double lat;
  final double lng;
  final double? speed;
  final double? heading;
  final DateTime? timestamp;

  /// Create GPS position
  GPSPositionModel({
    required this.vehicleId,
    required this.lat,
    required this.lng,
    this.speed,
    this.heading,
    this.timestamp,
  });

  /// Parse from JSON
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


/// Route status update
class RouteStatusUpdate {
  final String routeId;
  final String status;
  final String? reason;

  /// Create route status update
  RouteStatusUpdate({required this.routeId, required this.status, this.reason});

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        'status': status,
        if (reason != null) 'reason': reason,
      };
}


/// Trip prefs
class TripPrefs {
  final String minimize;
  final int maxTransfers;

  /// Create trip prefs
  TripPrefs({this.minimize = 'time', this.maxTransfers = 2});

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'minimize': minimize,
        'max_transfers': maxTransfers,
      };
}

/// Trip plan request
class TripPlanRequest {
  final GeoJSONPoint origin;
  final GeoJSONPoint destination;
  final DateTime preferredArrival;
  final TripPrefs preferences;

  /// Create trip plan request
  TripPlanRequest({
    required this.origin,
    required this.destination,
    required this.preferredArrival,
    required this.preferences,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'origin': origin.toJson(),
        'destination': destination.toJson(),
        'preferred_arrival': preferredArrival.toIso8601String(),
        'preferences': preferences.toJson(),
      };
}

/// Route leg
class RouteLeg {
  final String routeId;
  final String routeName;
  final StopModel boardStop;
  final StopModel alightStop;
  final int etaMin;
  final double fare;

  /// Create route leg
  RouteLeg({
    required this.routeId,
    required this.routeName,
    required this.boardStop,
    required this.alightStop,
    required this.etaMin,
    required this.fare,
  });

  /// Parse from JSON
  factory RouteLeg.fromJson(Map<String, dynamic> json) => RouteLeg(
        routeId: json['route_id'],
        routeName: json['route_name'],
        boardStop: StopModel.fromJson(json['board_stop']),
        alightStop: StopModel.fromJson(json['alight_stop']),
        etaMin: json['eta_min'],
        fare: json['fare'].toDouble(),
      );
}

/// Route option
class RouteOption {
  final int rank;
  final List<RouteLeg> legs;
  final int totalEtaMin;
  final double totalFare;
  final int transfers;

  /// Create route option
  RouteOption({
    required this.rank,
    required this.legs,
    required this.totalEtaMin,
    required this.totalFare,
    required this.transfers,
  });

  /// Parse from JSON
  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        rank: json['rank'],
        legs: (json['legs'] as List).map((l) => RouteLeg.fromJson(l)).toList(),
        totalEtaMin: json['total_eta_min'],
        totalFare: json['total_fare'].toDouble(),
        transfers: json['transfers'],
      );
}

/// Trip plan response
class TripPlanResponse {
  final List<RouteOption> options;
  final DateTime generatedAt;

  /// Create trip plan response
  TripPlanResponse({required this.options, required this.generatedAt});

  /// Parse from JSON
  factory TripPlanResponse.fromJson(Map<String, dynamic> json) =>
      TripPlanResponse(
        options: (json['options'] as List)
            .map((o) => RouteOption.fromJson(o))
            .toList(),
        generatedAt: DateTime.parse(json['generated_at']),
      );
}


/// Feedback create
class FeedbackCreate {
  final String routeId;
  final String message;
  final String category;
  final GeoJSONPoint? location;

  /// Create feedback create
  FeedbackCreate({
    required this.routeId,
    required this.message,
    required this.category,
    this.location,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
        'route_id': routeId,
        'message': message,
        'category': category,
        if (location != null) 'location': location!.toJson(),
      };
}

/// Feedback response
class FeedbackResponse {
  final String id;
  final String routeId;
  final String message;
  final String category;
  final String status;

  /// Create feedback response
  FeedbackResponse({
    required this.id,
    required this.routeId,
    required this.message,
    required this.category,
    required this.status,
  });

  /// Parse from JSON
  factory FeedbackResponse.fromJson(Map<String, dynamic> json) =>
      FeedbackResponse(
        id: json['id'],
        routeId: json['route_id'],
        message: json['message'],
        category: json['category'],
        status: json['status'],
      );
}


/// Announcement model
class Announcement {
  final String id;
  final String title;
  final String message;
  final String? targetRole;
  final DateTime expiresAt;

  /// Create announcement
  Announcement({
    required this.id,
    required this.title,
    required this.message,
    this.targetRole,
    required this.expiresAt,
  });

  /// Parse from JSON
  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json['id'],
        title: json['title'],
        message: json['message'],
        targetRole: json['target_role'],
        expiresAt: DateTime.parse(json['expires_at']),
      );
}