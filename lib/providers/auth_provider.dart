// lib/providers/auth_provider.dart
//
// This is the bridge between your screens and ApiService. Screens never
// call ApiService directly — they call AuthProvider methods, and
// AuthProvider calls ApiService underneath, then updates its own state
// and calls notifyListeners() so any widget watching it rebuilds
// automatically (e.g. a splash screen showing a spinner while
// isLoading is true, or the router redirecting once isAuthenticated
// flips to true).
//
// KNOWN GAP (flagging honestly rather than guessing):
// TokenResponse only contains {access_token, refresh_token, token_type,
// role, expires_in} — there's no email/name in it, and none of
// the 19 ApiService methods fetch "my own profile." So `currentUser`
// stays null right after login; you only reliably get `role` from the
// token response. If a Profile screen needs full user details later,
// ask your backend teammate whether a GET /auth/me or GET /users/me
// endpoint exists or needs to be added — don't guess an endpoint name.

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AuthStatus { unknown, authenticated, guest, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService;

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

  // ---------------------------------------------------------------
  // LOGIN (email + password)
  // ---------------------------------------------------------------
  // Deliberately does NOT catch errors here — LoginScreen's own
  // _handleLogin() already wraps this call in try/catch and shows its
  // own ErrorBanner text ("Invalid email or password.").
  // If we swallowed the error here too, the screen would never know
  // the call failed and would incorrectly proceed as if login worked.
  //
  // `rememberMe` is accepted to match LoginScreen's callback signature,
  // but nothing in your backend spec currently uses it — flag this
  // with your team; for now it's a no-op placeholder.
  Future<void> login(
    String email,
    String password, {
    bool rememberMe = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final tokens = await _apiService.login(email, password);
      _role = tokens.role;
      _isGuest = false;
      _status = AuthStatus.authenticated;
    } finally {
      // Runs whether login succeeded or threw — guarantees isLoading
      // always resets, so the UI never gets stuck on a spinner.
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // LOGIN, TWO-FACTOR STEP
  // ---------------------------------------------------------------
  // login() throws TwoFactorRequired when the account has two-factor on;
  // the emailed code is then confirmed here. Errors propagate so the
  // code screen can show them.
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

  // ---------------------------------------------------------------
  // GOOGLE SIGN-IN
  // ---------------------------------------------------------------
  // Takes the idToken as a parameter — the ACTUAL Google sign-in
  // popup/flow happens in main.dart's wiring (using the google_sign_in
  // package), not here. This method only knows what to do once it has
  // a token, matching separation of concerns: AuthProvider talks to
  // YOUR backend, not to Google directly.
  /// Set by the register screen while its User Agreement / Privacy Policy
  /// box is ticked. Google sign-in finishes outside that screen (see
  /// app_router.dart), so the agreement travels with it from here.
  bool googleSignUpTermsAccepted = false;

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

  // ---------------------------------------------------------------
  // GUEST MODE
  // ---------------------------------------------------------------
  // LoginScreen's onGuestContinue is a plain VoidCallback (not async),
  // so this method can't be `Future<void>` if we want to wire it
  // directly. State updates happen immediately and synchronously;
  // the SecureStorage clear is fire-and-forget in the background
  // since guests have nothing to clear 99% of the time anyway.
  void continueAsGuest() {
    _isGuest = true;
    _status = AuthStatus.guest;
    _apiService.continueAsGuest(); // fire-and-forget, not awaited
    notifyListeners();
  }

  // ---------------------------------------------------------------
  // REGISTER (commuter) — POST /auth/register
  // ---------------------------------------------------------------
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
          // The register screen only calls this once the box is ticked.
          acceptedTerms: true,
        ),
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------
  // FORGOT PASSWORD — POST /auth/forgot-password
  // ---------------------------------------------------------------
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

  // ---------------------------------------------------------------
  // VERIFY OTP / RESET — POST /auth/reset-password
  // ---------------------------------------------------------------
  // VerifyOtpScreen collects the 6-digit code, SetNewPasswordScreen the
  // new password; the backend checks both in this one call.
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

  // ---------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------
  // Never throws: ApiService clears the stored tokens even when the
  // server call fails, so the user is signed out locally either way and
  // the screen can always return to Login. Guests have no server
  // session, so they skip the call (it would only 401).
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

  // ---------------------------------------------------------------
  // SESSION CHECK (for SplashScreen — not built yet, but this is
  // what it will call to decide: go to /login, guest map, or dashboard)
  // ---------------------------------------------------------------
  Future<void> checkSession() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Attempting a silent refresh doubles as "is there a valid
      // session at all?" — if there's no refresh token or it's
      // expired, this throws and we fall through to unauthenticated.
      final tokens = await _apiService.refreshToken();
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