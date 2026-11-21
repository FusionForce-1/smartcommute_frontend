// App router
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/set_new_password_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/commuter/commuter_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';
import '../services/api_service.dart' show TwoFactorRequired;
import '../services/google_auth_services.dart';

const String _operatorUseWebPortal =
    'Operator accounts use the Smart Commute web portal. '
    'Please sign in there to manage your fleet.';

/// Smart commute auth app
class SmartCommuteAuthApp extends StatefulWidget {
  /// Create smart commute auth
  const SmartCommuteAuthApp({super.key});

  /// Create widget state
  @override
  State<SmartCommuteAuthApp> createState() => _SmartCommuteAuthAppState();
}

/// Smart commute auth state
class _SmartCommuteAuthAppState extends State<SmartCommuteAuthApp> {
  final AuthProvider _authProvider = AuthProvider();

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool _restoring = true;

  /// Initialize widget state
  @override
  void initState() {
    super.initState();
    _setUpGoogleSignIn();
    _restoreSession();
  }

  /// Restore remembered session
  Future<void> _restoreSession() async {
    await _authProvider.checkSession();
    if (!mounted) return;
    setState(() => _restoring = false);
    if (_authProvider.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _navigateToDashboard(_authProvider.role));
    }
  }

  /// Set up Google sign in
  Future<void> _setUpGoogleSignIn() async {
    try {
      await GoogleAuthService.instance.initialize();
    } catch (e) {
      debugPrint('GoogleAuthService.initialize() failed: $e');
      return;
    }

    _listenForNextGoogleSignIn();
  }

  /// Listen next Google sign
  void _listenForNextGoogleSignIn() {
    GoogleAuthService.instance.signInAndGetIdToken().then((idToken) async {
      if (idToken == null) return;
      try {
        await _authProvider.loginWithGoogle(idToken);
      } on TwoFactorRequired catch (challenge) {
        await _navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => TwoFactorLoginHost(challenge: challenge)),
        );
        return;
      }
      _navigateToDashboard(_authProvider.role);
    }).catchError((Object e) {
      debugPrint('Google sign-in failed: $e');
      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(_googleErrorMessage(e))),
      );
    }).whenComplete(() {
      if (mounted) _listenForNextGoogleSignIn();
    });
  }

  /// Google error message
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
      if ((status == 409 || status == 429) && detail != null) return detail.toString();
      return 'Google sign-in failed (HTTP $status).';
    }
    if (e is GoogleSignInException) {
      return 'Google sign-in failed: ${e.description ?? e.code.name}';
    }
    return 'Google sign-in failed. Try again.';
  }

  /// Navigate to dashboard
  void _navigateToDashboard(String? role, {bool isGuest = false}) {
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    if (role == 'operator') {
      _authProvider.logout();
      _scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text(_operatorUseWebPortal)),
      );
      return;
    }
    Widget destination;
    switch (role) {
      case 'driver':
        destination = const DriverDashboard();
        break;
      case 'commuter':
      default:
        destination = CommuterDashboard(isGuest: isGuest);
        break;
    }
    navigator.pushReplacement(MaterialPageRoute(builder: (_) => destination));
  }

  /// Clean up resources
  @override
  void dispose() {
    GoogleAuthService.instance.dispose();
    super.dispose();
  }

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: _authProvider,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _scaffoldMessengerKey,
        title: 'Smart Commute',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: _restoring
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : const LoginScreenHost(),
      ),
    );
  }
}

/// Open dashboard for role
void _openDashboardForRole(BuildContext context, String? role, {bool isGuest = false}) {
  if (role == 'operator') {
    context.read<AuthProvider>().logout();
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(_operatorUseWebPortal)),
    );
    return;
  }
  Widget destination;
  switch (role) {
    case 'driver':
      destination = const DriverDashboard();
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

/// Login screen host widget
class LoginScreenHost extends StatelessWidget {
  /// Create login host
  const LoginScreenHost({super.key});

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return LoginScreen(
      onLogin: (email, password, rememberMe) async {
        try {
          await auth.login(email, password, rememberMe: rememberMe);
        } on TwoFactorRequired catch (challenge) {
          if (!context.mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TwoFactorLoginHost(challenge: challenge)),
          );
          return;
        }
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

/// Register screen host widget
class RegisterScreenHost extends StatelessWidget {
  /// Create register host
  const RegisterScreenHost({super.key});

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return RegisterScreen(
      onBack: () => Navigator.of(context).pop(),
      onConsentChanged: (agreed) => auth.googleSignUpTermsAccepted = agreed,
      onRegister: (fullName, email, password) async {
        await auth.registerCommuter(
          fullName: fullName,
          email: email,
          password: password,
        );
        await auth.login(email, password);
        if (!context.mounted) return;
        _openDashboardForRole(context, auth.role);
      },
    );
  }
}

/// Forgot password host widget
class ForgotPasswordHost extends StatelessWidget {
  /// Create forgot password host
  const ForgotPasswordHost({super.key});

  /// Build the widget
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

/// Verify OTP host widget
class VerifyOtpHost extends StatelessWidget {
  /// Create verify OTP host
  const VerifyOtpHost({super.key, required this.email});

  final String email;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    return VerifyOtpScreen(
      email: email,
      onBack: () => Navigator.of(context).pop(),
      onVerifyOtp: (otp) async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SetNewPasswordHost(email: email, otp: otp),
          ),
        );
      },
    );
  }
}

/// Set new password host widget
class SetNewPasswordHost extends StatelessWidget {
  /// Create set new password
  const SetNewPasswordHost({super.key, required this.email, required this.otp});

  final String email;
  final String otp;

  /// Build the widget
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    return SetNewPasswordScreen(
      onBack: () => Navigator.of(context).pop(),
      onResetPassword: (newPassword) async {
        await auth.verifyOtpAndResetPassword(
          email: email,
          otp: otp,
          newPassword: newPassword,
        );
        if (!context.mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset. You can log in with your new password.'),
          ),
        );
      },
    );
  }
}

/// Two factor login host widget
class TwoFactorLoginHost extends StatelessWidget {
  /// Create two factor login
  const TwoFactorLoginHost({super.key, required this.challenge});

  final TwoFactorRequired challenge;

  /// Build the widget
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
