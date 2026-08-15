// lib/main.dart
//
// Emae D. Calonia — UI preview entry point.
//
// This is a MOCK ROUTER, not the real F4 App Router & Navigation Guards
// (lib/router/app_router.dart) from the system layout spec. It exists so the
// four auth screens can be clicked through and previewed with no backend,
// no provider package, and no AuthProvider.checkSession() gate.
//
// TODO(Francis): replace this file's routing with the real F4 app_router.dart
// (go_router or Navigator 2.0 + role/guest guards), and replace every
// `// TODO(Francis)` callback below with the matching F1 ApiService / F3
// AuthProvider call. Nothing in lib/widgets or lib/screens needs to change to
// do that — the screens only expose plain callback params, they don't know
// about ApiService, Provider, or Dio.

import 'package:flutter/material.dart';
import 'config/theme_config.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_otp_screen.dart';

void main() {
  runApp(const SmartCommuteApp());
}

class SmartCommuteApp extends StatelessWidget {
  const SmartCommuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Commute',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // TODO(Francis): swap `home:` for SplashScreen -> AuthProvider.checkSession()
      // once the real router + auth state exist. For this UI preview we go
      // straight to LoginScreen.
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(
              // TODO(Francis): onLogin -> AuthProvider.login(usernameOrEmail, password)
              onLogin: null,
              // TODO(Francis): onGoogleSignIn -> AuthProvider.loginWithGoogle(idToken)
              onGoogleSignIn: null,
              // TODO(Francis): onGuestContinue -> AuthProvider.continueAsGuest()
              onGuestContinue: null,
              onForgotPassword: () =>
                  Navigator.of(context).pushNamed('/forgot-password'),
              onCreateAccount: () => Navigator.of(context).pushNamed('/register'),
            ),
        '/register': (context) => RegisterScreen(
              // TODO(Francis): onRegister -> ApiService.register(UserCreate(...))
              onRegister: null,
              // TODO(Francis): onGoogleSignIn -> ApiService.loginWithGoogle(idToken)
              onGoogleSignIn: null,
              onBack: () => Navigator.of(context).pop(),
            ),
        '/forgot-password': (context) => ForgotPasswordScreen(
              onBack: () => Navigator.of(context).pop(),
              // Preview-only: pretend the OTP send succeeded and jump straight to
              // VerifyOtpScreen so the click-through flow stays demoable.
              // TODO(Francis): replace with a real await ApiService call; only
              // navigate to /verify-otp on success, and surface failures (e.g.
              // "This email is not registered" per the Web_Forgot_Password /
              // Web_Error mockups) via the screen's built-in ErrorBanner instead.
              onSendOtp: (email) async {
                await Navigator.of(context)
                    .pushNamed('/verify-otp', arguments: email);
              },
            ),
        '/verify-otp': (context) {
          final email =
              ModalRoute.of(context)?.settings.arguments as String? ??
                  'account@gmail.com';
          return VerifyOtpScreen(
            email: email,
            onBack: () => Navigator.of(context).pop(),
            // TODO(Francis): onVerifyOtp -> AuthService.verify_otp() +
            // reset_password() flow, then Navigator back to /login on success.
            onVerifyOtp: null,
          );
        },
      },
    );
  }
}
