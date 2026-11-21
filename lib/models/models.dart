// Models model

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
