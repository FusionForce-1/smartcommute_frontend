// API service
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import 'dio_interceptor.dart';

/// Two factor required
class TwoFactorRequired implements Exception {
  /// Create two factor required
  const TwoFactorRequired({required this.email, required this.maskedEmail});

  final String email;

  final String maskedEmail;

  /// Readable text form
  @override
  String toString() => 'Two-factor code required for $maskedEmail';
}

/// API service
class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  /// Create API service
  ApiService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? buildDioClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();


  /// Login data
  Future<TokenResponse> login(String email, String password) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email.trim(),
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode == 202 && data['two_factor_required'] == true) {
      throw TwoFactorRequired(
        email: email.trim(),
        maskedEmail: data['email'] as String? ?? email.trim(),
      );
    }
    final tokens = TokenResponse.fromJson(data);
    await _storeTokens(tokens);
    return tokens;
  }

  /// Verify login code
  Future<TokenResponse> verifyLoginCode(String email, String otp) async {
    final response = await _dio.post('/auth/login/verify', data: {
      'email': email,
      'otp': otp,
    });
    final tokens = TokenResponse.fromJson(response.data);
    await _storeTokens(tokens);
    return tokens;
  }

  /// Login with Google
  Future<TokenResponse> loginWithGoogle(String idToken, {bool acceptedTerms = false}) async {
    final response = await _dio.post('/auth/google', data: {
      'id_token': idToken,
      if (acceptedTerms) 'accepted_terms': true,
    });
    final tokens = TokenResponse.fromJson(response.data);
    await _storeTokens(tokens);
    return tokens;
  }

  /// Register data
  Future<UserModel> register(UserCreate data) async {
    final response = await _dio.post('/auth/register', data: data.toJson());
    return UserModel.fromJson(response.data);
  }

  /// Continue as guest
  Future<void> continueAsGuest() async {
    await _secureStorage.deleteAll();
  }

  /// Refresh token
  Future<TokenResponse> refreshToken() async {
    final refreshTokenValue = await _secureStorage.read(key: 'refresh_token');
    if (refreshTokenValue == null) {
      throw Exception('No refresh token available — user must log in again');
    }
    final response = await _dio.post('/auth/refresh', data: {
      'refresh_token': refreshTokenValue,
    });
    final tokens = TokenResponse.fromJson(response.data);
    await _storeTokens(tokens);
    return tokens;
  }

  /// Logout data
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      await _secureStorage.deleteAll();
    }
  }

  /// Store tokens
  Future<void> _storeTokens(TokenResponse tokens) async {
    await _secureStorage.write(key: 'access_token', value: tokens.accessToken);
    await _secureStorage.write(key: 'refresh_token', value: tokens.refreshToken);
  }

  /// Send password reset OTP
  Future<void> sendPasswordResetOtp(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  /// Verify OTP and reset password
  Future<void> verifyOtpAndResetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    await _dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }


  /// Get routes
  Future<List<RouteModel>> getRoutes() async {
    final response = await _dio.get('/routes');
    return (response.data as List)
        .map((json) => RouteModel.fromJson(json))
        .toList();
  }

  /// Get route by ID
  Future<RouteModel> getRouteById(String id) async {
    final response = await _dio.get('/routes/$id');
    return RouteModel.fromJson(response.data);
  }

  /// Get stops
  Future<List<StopModel>> getStops({double? lat, double? lng, double? radiusMeters}) async {
    final response = await _dio.get('/stops', queryParameters: {
      if (lat != null && lng != null) 'near': '$lat,$lng',
      if (radiusMeters != null) 'radius': radiusMeters,
    });
    return (response.data as List)
        .map((json) => StopModel.fromJson(json))
        .toList();
  }

  /// Get vehicles
  Future<List<VehicleModel>> getVehicles({String? routeId}) async {
    final response = await _dio.get('/vehicles', queryParameters: {
      if (routeId != null) 'route_id': routeId,
    });
    return (response.data as List)
        .map((json) => VehicleModel.fromJson(json))
        .toList();
  }

  /// Get vehicle position
  Future<GPSPositionModel> getVehiclePosition(String id) async {
    final response = await _dio.get('/vehicles/$id/position');
    return GPSPositionModel.fromJson(response.data);
  }


  /// Plan trip
  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    final response = await _dio.post('/trip-plan', data: request.toJson());
    return TripPlanResponse.fromJson(response.data);
  }

  /// Submit feedback
  Future<FeedbackResponse> submitFeedback(FeedbackCreate feedback) async {
    final response = await _dio.post('/feedback', data: feedback.toJson());
    return FeedbackResponse.fromJson(response.data);
  }


  /// Get announcements
  Future<List<Announcement>> getAnnouncements() async {
    final response = await _dio.get('/announcements');
    return (response.data as List)
        .map((json) => Announcement.fromJson(json))
        .toList();
  }


  /// Update route status
  Future<void> updateRouteStatus(RouteStatusUpdate update) async {
    await _dio.patch('/route-status', data: update.toJson());
  }

  /// Get fleet
  Future<List<VehicleModel>> getFleet({String? operatorId}) async {
    final response = await _dio.get('/fleet', queryParameters: {
      if (operatorId != null) 'operator_id': operatorId,
    });
    return (response.data as List)
        .map((json) => VehicleModel.fromJson(json))
        .toList();
  }


  /// Get users
  Future<List<UserModel>> getUsers({String? role}) async {
    final response = await _dio.get('/users', queryParameters: {
      if (role != null) 'role': role,
    });
    return (response.data as List)
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  /// Update user
  Future<UserModel> updateUser(String id, UserUpdate update) async {
    final response = await _dio.patch('/users/$id', data: update.toJson());
    return UserModel.fromJson(response.data);
  }

  /// Verify operator
  Future<void> verifyOperator(String id) async {
    await _dio.post('/users/$id/verify');
  }

  /// Get reports
  Future<Map<String, dynamic>> getReports(String type) async {
    final endpoint = type == 'fleet' ? '/reports/fleet' : '/reports/system';
    final response = await _dio.get(endpoint);
    return response.data as Map<String, dynamic>;
  }
}