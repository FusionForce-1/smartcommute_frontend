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

const String rememberMeKey = 'remember_me';

/// API service
class ApiService {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  /// Create API service
  ApiService({Dio? dio, FlutterSecureStorage? secureStorage})
      : _dio = dio ?? buildDioClient(),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();


  bool _rememberMe = false;

  /// Login data
  Future<TokenResponse> login(String email, String password, {bool rememberMe = false}) async {
    _rememberMe = rememberMe;
    final response = await _dio.post('/auth/login', data: {
      'email': email.trim(),
      'password': password,
    });
    return _tokensOrChallenge(response, email.trim());
  }

  /// Tokens or 2FA challenge
  Future<TokenResponse> _tokensOrChallenge(Response response, String email) async {
    final data = response.data as Map<String, dynamic>;
    if (response.statusCode == 202 && data['two_factor_required'] == true) {
      throw TwoFactorRequired(
        email: data['login_email'] as String? ?? email,
        maskedEmail: data['email'] as String? ?? email,
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
    _rememberMe = true;
    final response = await _dio.post('/auth/google', data: {
      'id_token': idToken,
      if (acceptedTerms) 'accepted_terms': true,
    });
    return _tokensOrChallenge(response, '');
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

  /// Restore saved session
  Future<TokenResponse> restoreSession() async {
    if (await _secureStorage.read(key: rememberMeKey) != '1') {
      await _secureStorage.deleteAll();
      throw Exception('Not remembered: sign in again');
    }
    _rememberMe = true;
    return refreshToken();
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
      final refresh = await _secureStorage.read(key: 'refresh_token');
      await _dio.post('/auth/logout', data: {if (refresh != null) 'refresh_token': refresh});
    } finally {
      await _secureStorage.deleteAll();
    }
  }

  /// Store tokens
  Future<void> _storeTokens(TokenResponse tokens) async {
    await _secureStorage.write(key: 'access_token', value: tokens.accessToken);
    await _secureStorage.write(key: 'refresh_token', value: tokens.refreshToken);
    await _secureStorage.write(key: rememberMeKey, value: _rememberMe ? '1' : '0');
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
}
