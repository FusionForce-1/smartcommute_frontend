// lib/services/api_service.dart
//
// This is your F1 file. Every method here does the same 3 things:
//   1. Call `_dio.get/post/patch/delete(...)` with the right endpoint
//   2. Convert the raw JSON response into a typed model (from models.dart)
//   3. Let DioException bubble up uncaught — the SCREEN that calls this
//      method should wrap it in try/catch and show an error, since only
//      the screen knows how to display that error appropriately.
//      (The DioInterceptor from Step 2 already handles token refresh
//      and 401/403 transparently underneath, so you don't repeat that
//      logic here.)

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';
import 'dio_interceptor.dart';
import 'mock_auth_adapter.dart';

/// Thrown by [ApiService.login] when the account has two-factor
/// authentication on: a code was emailed and must be confirmed with
/// [ApiService.verifyLoginCode] before the user is signed in.
class TwoFactorRequired implements Exception {
  const TwoFactorRequired({required this.email, required this.maskedEmail});

  /// The email the user signed in with (sent back with the code).
  final String email;

  /// Where the code went, e.g. "op******@cebulines.ph".
  final String maskedEmail;

  @override
  String toString() => 'Two-factor code required for $maskedEmail';
}

class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;
  final MockAuthAdapter _authMocks;

  /// TODO: Velez — set to false when FastAPI auth endpoints are live.
  /// Keep mocks inside this Francis-owned service layer, never in main.dart.
  static const bool useAuthMocks = false;

  // Constructor takes the pre-configured Dio from dio_interceptor.dart
  // rather than building its own — this way there's only ONE Dio
  // instance (with the interceptor attached) for the whole app.
  ApiService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? buildDioClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _authMocks = MockAuthAdapter();

  // =================================================================
  // AUTH (6 methods)
  // =================================================================

  Future<TokenResponse> login(String email, String password) async {
    if (useAuthMocks) {
      final tokens = await _authMocks.login(email, password);
      await _storeTokens(tokens);
      return tokens;
    }
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

  /// Second step of a two-factor login: POST /auth/login/verify.
  Future<TokenResponse> verifyLoginCode(String email, String otp) async {
    final response = await _dio.post('/auth/login/verify', data: {
      'email': email,
      'otp': otp,
    });
    final tokens = TokenResponse.fromJson(response.data);
    await _storeTokens(tokens);
    return tokens;
  }

  /// [acceptedTerms]: sent from the register screen once its User
  /// Agreement / Privacy Policy box is ticked; the backend records it.
  Future<TokenResponse> loginWithGoogle(String idToken, {bool acceptedTerms = false}) async {
    if (useAuthMocks) {
      final tokens = await _authMocks.loginWithGoogle(idToken);
      await _storeTokens(tokens);
      return tokens;
    }
    final response = await _dio.post('/auth/google', data: {
      'id_token': idToken,
      if (acceptedTerms) 'accepted_terms': true,
    });
    final tokens = TokenResponse.fromJson(response.data);
    await _storeTokens(tokens);
    return tokens;
  }

  Future<UserModel> register(UserCreate data) async {
    if (useAuthMocks) {
      return _authMocks.register(data);
    }
    final response = await _dio.post('/auth/register', data: data.toJson());
    // Backend returns UserResponse — registration does NOT log the user
    // in automatically (no tokens in this response), so we just return
    // the created user; AuthProvider should route to /login after this.
    return UserModel.fromJson(response.data);
  }

  // No API call at all — this is purely local state. It lives here
  // (rather than only in AuthProvider) so AuthProvider stays focused
  // on STATE, while ApiService stays focused on "talks to network or
  // storage." Guests simply never call _storeTokens, so onRequest in
  // the interceptor finds nothing in SecureStorage and sends no header.
  Future<void> continueAsGuest() async {
    await _secureStorage.deleteAll();
  }

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

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      // Clear local tokens even if the network call fails (e.g. no
      // internet) — the user still expects to be logged out locally.
      await _secureStorage.deleteAll();
    }
  }

  // Small private helper so login/loginWithGoogle/refreshToken don't
  // each repeat the same two secureStorage.write calls.
  Future<void> _storeTokens(TokenResponse tokens) async {
    await _secureStorage.write(key: 'access_token', value: tokens.accessToken);
    await _secureStorage.write(key: 'refresh_token', value: tokens.refreshToken);
  }

  // NOT in the original 19-method F1 list — added to support
  // ForgotPasswordScreen.onSendOtp, which needs SOME network call to
  // exist. Endpoint path/shape is my best guess from the screen file's
  // own comment ("POST /auth/forgot-password -> HTTP 202"); confirm
  // the exact path and response shape with your backend teammate.
  Future<void> sendPasswordResetOtp(String email) async {
    if (useAuthMocks) {
      await _authMocks.sendPasswordResetOtp(email);
      return;
    }
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  // The backend needs email + otp + new_password together in one call
  // (new_password at least 6 characters, or it answers 422). The code
  // comes from VerifyOtpScreen, the password from SetNewPasswordScreen.
  Future<void> verifyOtpAndResetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    if (useAuthMocks) {
      await _authMocks.verifyOtpAndResetPassword(email, otp, newPassword);
      return;
    }
    await _dio.post('/auth/reset-password', data: {
      'email': email,
      'otp': otp,
      'new_password': newPassword,
    });
  }

  // =================================================================
  // ROUTES / STOPS / VEHICLES (5 methods) — work for guests too
  // =================================================================

  Future<List<RouteModel>> getRoutes() async {
    final response = await _dio.get('/routes');
    return (response.data as List)
        .map((json) => RouteModel.fromJson(json))
        .toList();
  }

  Future<RouteModel> getRouteById(String id) async {
    final response = await _dio.get('/routes/$id');
    return RouteModel.fromJson(response.data);
  }

  Future<List<StopModel>> getStops({double? lat, double? lng, double? radiusMeters}) async {
    final response = await _dio.get('/stops', queryParameters: {
      // Only attach ?near=... if the caller actually wants a
      // proximity search — otherwise fetch the full stop list.
      if (lat != null && lng != null) 'near': '$lat,$lng',
      if (radiusMeters != null) 'radius': radiusMeters,
    });
    return (response.data as List)
        .map((json) => StopModel.fromJson(json))
        .toList();
  }

  Future<List<VehicleModel>> getVehicles({String? routeId}) async {
    final response = await _dio.get('/vehicles', queryParameters: {
      if (routeId != null) 'route_id': routeId,
    });
    return (response.data as List)
        .map((json) => VehicleModel.fromJson(json))
        .toList();
  }

  Future<GPSPositionModel> getVehiclePosition(String id) async {
    final response = await _dio.get('/vehicles/$id/position');
    return GPSPositionModel.fromJson(response.data);
  }

  // =================================================================
  // TRIP PLANNING & FEEDBACK (2 methods) — require commuter login
  // =================================================================

  Future<TripPlanResponse> planTrip(TripPlanRequest request) async {
    // NOTE: this endpoint requires a logged-in commuter. If a guest
    // reaches this method, the backend will return 401 — TripProvider
    // (built in a later step) is responsible for checking
    // AuthProvider.isGuest BEFORE calling this and redirecting to
    // login instead, so the user gets a clear prompt rather than a
    // confusing network error.
    final response = await _dio.post('/trip-plan', data: request.toJson());
    return TripPlanResponse.fromJson(response.data);
  }

  Future<FeedbackResponse> submitFeedback(FeedbackCreate feedback) async {
    final response = await _dio.post('/feedback', data: feedback.toJson());
    return FeedbackResponse.fromJson(response.data);
  }

  // =================================================================
  // ANNOUNCEMENTS (1 method) — works for guests too
  // =================================================================

  Future<List<Announcement>> getAnnouncements() async {
    final response = await _dio.get('/announcements');
    return (response.data as List)
        .map((json) => Announcement.fromJson(json))
        .toList();
  }

  // =================================================================
  // DRIVER / OPERATOR (2 methods)
  // =================================================================

  Future<void> updateRouteStatus(RouteStatusUpdate update) async {
    await _dio.patch('/route-status', data: update.toJson());
  }

  Future<List<VehicleModel>> getFleet({String? operatorId}) async {
    final response = await _dio.get('/fleet', queryParameters: {
      if (operatorId != null) 'operator_id': operatorId,
    });
    return (response.data as List)
        .map((json) => VehicleModel.fromJson(json))
        .toList();
  }

  // =================================================================
  // ADMIN (4 methods)
  // =================================================================

  Future<List<UserModel>> getUsers({String? role}) async {
    final response = await _dio.get('/users', queryParameters: {
      if (role != null) 'role': role,
    });
    return (response.data as List)
        .map((json) => UserModel.fromJson(json))
        .toList();
  }

  Future<UserModel> updateUser(String id, UserUpdate update) async {
    final response = await _dio.patch('/users/$id', data: update.toJson());
    return UserModel.fromJson(response.data);
  }

  Future<void> verifyOperator(String id) async {
    await _dio.post('/users/$id/verify');
  }

  Future<Map<String, dynamic>> getReports(String type) async {
    // type is "fleet" or "system" — matches the two backend endpoints
    final endpoint = type == 'fleet' ? '/reports/fleet' : '/reports/system';
    final response = await _dio.get(endpoint);
    return response.data as Map<String, dynamic>;
  }
}