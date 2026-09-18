// lib/screens/auth/auth_app.dart
//
// Emae D. Calonia — click-through navigator for the four auth screens.
// Navigation only lives here. API mocks live in Francis's MockAuthAdapter
// (via AuthProvider / ApiService) — not in main.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme_config.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/verify_otp_screen.dart';
import '../screens/commuter/commuter_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';

class SmartCommuteAuthApp extends StatelessWidget {
  const SmartCommuteAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
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
        await auth.login(email, password, rememberMe: rememberMe);
        if (!context.mounted) return;
        _openDashboardForRole(context, auth.role);
      },
      onGoogleSignIn: () async {
        // TODO [Velez]: replace 'preview-google-id-token' with google_sign_in
        await auth.loginWithGoogle('preview-google-id-token');
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
        if (!context.mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created. Please log in.')),
        );
      },
      onGoogleSignIn: () async {
        await auth.loginWithGoogle('preview-google-id-token');
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
