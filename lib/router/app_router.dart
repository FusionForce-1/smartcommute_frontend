// lib/screens/auth/auth_app.dart
//
// Emae D. Calonia — click-through navigator for the four auth screens.
// Navigation only lives here. API mocks live in Francis's MockAuthAdapter
// (via AuthProvider / ApiService) — not in main.dart.
//
// FIXED by Francis: Google Sign-In on web needs two things wired up at
// startup that were previously missing entirely — see _setUpGoogleSignIn()
// below for why.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:smartcommute_app/screens/operator/operator_dashboard.dart';
import '../config/theme_config.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/commuter/commuter_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';
import '../services/api_service.dart' show TwoFactorRequired;
import '../services/google_auth_services.dart';

class SmartCommuteAuthApp extends StatefulWidget {
  const SmartCommuteAuthApp({super.key});

  @override
  State<SmartCommuteAuthApp> createState() => _SmartCommuteAuthAppState();
}

class _SmartCommuteAuthAppState extends State<SmartCommuteAuthApp> {
  // Held directly as a field instead of via context.read() — this
  // widget's own `context` sits ABOVE where ChangeNotifierProvider and
  // MaterialApp get created (they're built INSIDE build() below), so
  // context.read<AuthProvider>() from here can never find it. Holding
  // the instance directly sidesteps needing a context at all.
  final AuthProvider _authProvider = AuthProvider();

  // Same reasoning for navigation: Navigator.of(context) needs a
  // context that's a DESCENDANT of the Navigator MaterialApp creates.
  // This widget's own context isn't. A GlobalKey lets us reach the
  // Navigator directly regardless of where we're calling from.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  // Same idea for SnackBars shown from the Google callback above.
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _setUpGoogleSignIn();
  }

  Future<void> _setUpGoogleSignIn() async {
    try {
      await GoogleAuthService.instance.initialize();
    } catch (e) {
      debugPrint('GoogleAuthService.initialize() failed: $e');
      return;
    }

    _listenForNextGoogleSignIn();
  }

  // signInAndGetIdToken() resolves ONCE per call — it's a one-shot
  // listener, not a persistent subscription. The first time this ran,
  // it correctly caught your Register-screen Google click and routed
  // you in. But after that single Future resolved, nothing was left
  // listening, so the NEXT Google click (from Login) had no one to
  // report back to. Calling this again after every result — success
  // or not — keeps a fresh listener always armed for the next attempt.
  //
  // Re-arming happens in whenComplete so it also runs when the sign-in
  // FAILS — previously a single backend rejection (e.g. 401) skipped the
  // re-arm and Google sign-in silently stopped working until reload.
  void _listenForNextGoogleSignIn() {
    GoogleAuthService.instance.signInAndGetIdToken().then((idToken) async {
      if (idToken == null) return; // user closed the popup
      await _authProvider.loginWithGoogle(idToken);
      _navigateToDashboard(_authProvider.role);
    }).catchError((Object e) {
      debugPrint('Google sign-in failed: $e');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(_googleErrorMessage(e))),
      );
    }).whenComplete(() {
      if (mounted) _listenForNextGoogleSignIn(); // re-arm for next time
    });
  }

  static String _googleErrorMessage(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final detail = e.response?.data is Map ? e.response?.data['detail'] : null;
      if (status == null) {
        return "Can't reach the server. Check that the backend is running.";
      }
      if (status == 401) {
        return 'Google sign-in was rejected by the server'
            '${detail != null ? ': $detail' : '.'}';
      }
      if (status == 403) return detail?.toString() ?? 'Account is not allowed.';
      return 'Google sign-in failed (HTTP $status).';
    }
    if (e is GoogleSignInException) {
      return 'Google sign-in failed: ${e.description ?? e.code.name}';
    }
    return 'Google sign-in failed. Try again.';
  }

  // Uses the GlobalKey instead of a BuildContext — works correctly
  // even when called from outside the widget tree (like the callback
  // above), unlike Navigator.of(context) would from this State.
  void _navigateToDashboard(String? role, {bool isGuest = false}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return; // not mounted yet — shouldn't happen in practice
    Widget destination;
    switch (role) {
      case 'driver':
        destination = const DriverDashboard();
        break;
      case 'operator':
        destination = const OperatorDashboard();
        break;
      case 'commuter':
      default:
        destination = CommuterDashboard(isGuest: isGuest);
        break;
    }
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  @override
  void dispose() {
    GoogleAuthService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      // .value (not create:) because we already constructed this
      // instance above as a field — using create: here would make a
      // SECOND, different AuthProvider that _setUpGoogleSignIn()
      // never touches, leaving the UI watching the wrong instance.
      value: _authProvider,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        title: 'Smart Commute',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const LoginScreenHost(),
      ),
    );
  }
}

/// Routes to the role-appropriate test dashboard after authentication.
void _openDashboardForRole(BuildContext context, String? role, {bool isGuest = false}) {
  Widget destination;
  switch (role) {
    case 'driver':
      destination = const DriverDashboard();
      break;
    case 'operator':
      destination = const OperatorDashboard();
      break;
    case 'commuter':
    default:
      destination = CommuterDashboard(isGuest: isGuest);
      break;
  }
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => destination),
  );
}

class LoginScreenHost extends StatelessWidget {
  const LoginScreenHost({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return LoginScreen(
      onLogin: (email, password, rememberMe) async {
        try {
          await auth.login(email, password, rememberMe: rememberMe);
        } on TwoFactorRequired catch (challenge) {
          // Password was right; the account wants the emailed code too.
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TwoFactorLoginHost(challenge: challenge)),
          );
          return;
        }
        if (!context.mounted) return;
        _openDashboardForRole(context, auth.role);
      },
      // NOTE: this callback is effectively DEAD CODE on web now — see
      // _setUpGoogleSignIn() above, which handles the whole web flow
      // independently since GoogleSignInButton has no onPressed to
      // trigger this. Kept here only in case a non-web platform later
      // uses a real clickable button that calls this directly.
      onGoogleSignIn: () async {
        final idToken = await GoogleAuthService.instance.signInAndGetIdToken();
        if (idToken == null) return;
        await auth.loginWithGoogle(idToken);
        if (!context.mounted) return;
        _openDashboardForRole(context, auth.role);
      },
      onGuestContinue: () {
        auth.continueAsGuest();
        _openDashboardForRole(context, 'commuter', isGuest: true);
      },
      onForgotPassword: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ForgotPasswordHost()),
        );
      },
      onCreateAccount: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const RegisterScreenHost()),
        );
      },
    );
  }
}

class RegisterScreenHost extends StatelessWidget {
  const RegisterScreenHost({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return RegisterScreen(
      onBack: () => Navigator.of(context).pop(),
      onRegister: (fullName, email, password) async {
        await auth.registerCommuter(
          fullName: fullName,
          email: email,
          password: password,
        );
        // registerCommuter() only creates the account — your backend's
        // /auth/register does NOT return tokens, so the user isn't
        // actually logged in yet at this point. We immediately log
        // them in with the same credentials they just typed, so
        // registering feels like one continuous action instead of
        // "create account, then go type your password again."
        await auth.login(email, password);
        if (!context.mounted) return;
        _openDashboardForRole(context, auth.role);
      },
      onGoogleSignIn: () async {
        final idToken = await GoogleAuthService.instance.signInAndGetIdToken();
        if (idToken == null) return;
        await auth.loginWithGoogle(idToken);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      },
    );
  }
}

class ForgotPasswordHost extends StatelessWidget {
  const ForgotPasswordHost({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return ForgotPasswordScreen(
      onBack: () => Navigator.of(context).pop(),
      onSendOtp: (email) async {
        await auth.sendPasswordResetOtp(email);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyOtpHost(email: email),
          ),
        );
      },
    );
  }
}

class VerifyOtpHost extends StatelessWidget {
  const VerifyOtpHost({super.key, required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return VerifyOtpScreen(
      email: email,
      onBack: () => Navigator.of(context).pop(),
      onVerifyOtp: (otp) async {
        await auth.verifyOtpAndResetPassword(email: email, otp: otp);
        if (!context.mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP verified. You can log in.')),
        );
      },
    );
  }
}
/// Second sign-in step for accounts with two-factor authentication on.
class TwoFactorLoginHost extends StatelessWidget {
  const TwoFactorLoginHost({super.key, required this.challenge});

  final TwoFactorRequired challenge;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return VerifyOtpScreen(
      title: 'VERIFY\nSIGN-IN',
      email: challenge.maskedEmail,
      onBack: () => Navigator.of(context).pop(),
      onVerifyOtp: (otp) async {
        await auth.verifyLoginCode(challenge.email, otp);
        if (!context.mounted) return;
        _openDashboardForRole(context, auth.role);
      },
    );
  }
}
