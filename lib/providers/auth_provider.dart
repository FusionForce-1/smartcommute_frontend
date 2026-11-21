// Auth provider
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

/// Auth status
enum AuthStatus { unknown, authenticated, guest, unauthenticated }

/// Auth provider
class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

  /// Create auth
  AuthProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  UserModel? _currentUser;
  String? _role;
  bool _isGuest = false;
  bool _isLoading = false;
  AuthStatus _status = AuthStatus.unknown;

  UserModel? get currentUser => _currentUser;
  String? get role => _role;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isGuest => _isGuest;
  bool get isLoading => _isLoading;
  AuthStatus get status => _status;

  /// Login auth
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await _apiService.login(email, password, rememberMe: rememberMe);
      _role = tokens.role;
      _isGuest = false;
      _status = AuthStatus.authenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verify login code
  Future<void> verifyLoginCode(String email, String otp) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await _apiService.verifyLoginCode(email, otp);
      _role = tokens.role;
      _isGuest = false;
      _status = AuthStatus.authenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool googleSignUpTermsAccepted = false;

  /// Login with Google
  Future<void> loginWithGoogle(String idToken) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await _apiService.loginWithGoogle(
        idToken,
        acceptedTerms: googleSignUpTermsAccepted,
      );
      _role = tokens.role;
      _isGuest = false;
      _status = AuthStatus.authenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Continue as guest
  void continueAsGuest() {
    _isGuest = true;
    _status = AuthStatus.guest;
    _apiService.continueAsGuest();
    notifyListeners();
  }

  /// Register commuter
  Future<void> registerCommuter({
    required String fullName,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.register(
        UserCreate(
          email: email.trim(),
          password: password,
          name: fullName.trim(),
          acceptedTerms: true,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Send password reset OTP
  Future<void> sendPasswordResetOtp(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.sendPasswordResetOtp(email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Verify OTP and reset password
  Future<void> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.verifyOtpAndResetPassword(email, otp, newPassword);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logout auth
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!_isGuest) await _apiService.logout();
    } catch (e) {
      debugPrint('Server logout failed, signed out locally: $e');
    } finally {
      _currentUser = null;
      _role = null;
      _isGuest = false;
      _status = AuthStatus.unauthenticated;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check session
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await _apiService.restoreSession();
      _role = tokens.role;
      _isGuest = false;
      _status = AuthStatus.authenticated;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}