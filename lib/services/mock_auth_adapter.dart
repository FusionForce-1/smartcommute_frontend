// lib/services/mock_auth_adapter.dart
//
// FRANCIS B. VELEZ — mock data adapter (F1 companion).
// Preview responses for Emae's auth screens so the UI can be clicked
// through without FastAPI. Swap this file's internals for live Dio calls
// inside api_service.dart (this adapter is already the seam).
//
// NEVER import this from main.dart / app_router.dart / theme / widgets.
// ApiService is the only production caller.
//
// Demo accounts (UI preview only):
//   commuter@gmail.com / password123   → role: commuter
//   driver@gmail.com   / password123   → role: driver
//   operator@gmail.com / password123   → role: operator
// Forgot-password error fixture (matches web mockup):
//   test@account.com → "This email is not registered"
// OTP fixture: "123456" succeeds; anything else fails.

import '../models/models.dart';

class MockAuthException implements Exception {
  MockAuthException(this.message, {this.statusCode = 400});
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class MockAuthAdapter {
  static const Duration networkDelay = Duration(milliseconds: 450);

  static const String _demoPassword = 'password123';
  static const String _demoOtp = '123456';

  final Map<String, _MockUser> _users = {
    'commuter@gmail.com': _MockUser(
      email: 'commuter@gmail.com',
      password: _demoPassword,
      role: 'commuter',
      firstName: 'Emae',
      lastName: 'Calonia',
    ),
    'driver@gmail.com': _MockUser(
      email: 'driver@gmail.com',
      password: _demoPassword,
      role: 'driver',
      firstName: 'Juan',
      lastName: 'Driver',
    ),
    'operator@gmail.com': _MockUser(
      email: 'operator@gmail.com',
      password: _demoPassword,
      role: 'operator',
      firstName: 'Operator',
      lastName: 'Account',
    ),
    'account@gmail.com': _MockUser(
      email: 'account@gmail.com',
      password: _demoPassword,
      role: 'commuter',
      firstName: 'Demo',
      lastName: 'Commuter',
    ),
  };

  final Map<String, String> _issuedOtps = {};

  Future<void> _latency() => Future.delayed(networkDelay);

  Future<TokenResponse> login(String usernameOrEmail, String password) async {
    await _latency();
    final user = _users[usernameOrEmail.trim().toLowerCase()];
    if (user == null || user.password != password) {
      throw MockAuthException(
        'Invalid username/email or password.',
        statusCode: 401,
      );
    }
    return _tokensFor(user.role);
  }

  Future<TokenResponse> loginWithGoogle(String idToken) async {
    await _latency();
    if (idToken.trim().isEmpty) {
      throw MockAuthException('Google sign-in cancelled.', statusCode: 401);
    }
    return _tokensFor('commuter');
  }

  Future<UserModel> register(UserCreate data) async {
    await _latency();
    final email = data.email.trim().toLowerCase();
    if (_users.containsKey(email)) {
      throw MockAuthException('Email is already registered.', statusCode: 409);
    }
    _users[email] = _MockUser(
      email: email,
      password: data.password,
      role: 'commuter',
      firstName: data.firstName,
      lastName: data.lastName,
    );
    return UserModel(
      id: 'mock-${_users.length}',
      username: data.username,
      email: email,
      firstName: data.firstName,
      lastName: data.lastName,
      role: 'commuter',
      isActive: true,
      isVerified: false,
    );
  }

  Future<void> sendPasswordResetOtp(String email) async {
    await _latency();
    final normalized = email.trim().toLowerCase();
    if (normalized == 'test@account.com' || !_users.containsKey(normalized)) {
      throw MockAuthException(
        'This email is not registered',
        statusCode: 404,
      );
    }
    _issuedOtps[normalized] = _demoOtp;
  }

  Future<void> verifyOtpAndResetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    await _latency();
    final normalized = email.trim().toLowerCase();
    final expected = _issuedOtps[normalized] ?? _demoOtp;
    if (otp.trim() != expected) {
      throw MockAuthException(
        'Incorrect or expired code. Try again.',
        statusCode: 400,
      );
    }
    final user = _users[normalized];
    if (user != null && newPassword.isNotEmpty) {
      _users[normalized] = user.copyWith(password: newPassword);
    }
    _issuedOtps.remove(normalized);
  }

  TokenResponse _tokensFor(String role) => TokenResponse(
        accessToken: 'mock-access-$role',
        refreshToken: 'mock-refresh-$role',
        tokenType: 'bearer',
        role: role,
        expiresIn: 3600,
      );
}

class _MockUser {
  const _MockUser({
    required this.email,
    required this.password,
    required this.role,
    required this.firstName,
    required this.lastName,
  });

  final String email;
  final String password;
  final String role;
  final String firstName;
  final String lastName;

  _MockUser copyWith({String? password}) => _MockUser(
        email: email,
        password: password ?? this.password,
        role: role,
        firstName: firstName,
        lastName: lastName,
      );
}
