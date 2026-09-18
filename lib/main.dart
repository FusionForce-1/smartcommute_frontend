// lib/main.dart
//
// UPDATED: TODOs replaced with real AuthProvider / ApiService calls.
// Still using the same simple named-route setup Emae had — NOT yet the
// real F4 app_router.dart with role guards. That's a separate step
// once AuthProvider exists and is proven to work (this file).
//
// KNOWN GAPS — do not treat these as "done," see inline comments:
//   1. Google Sign-In: requires google_sign_in package + Firebase/Google
//      Cloud OAuth client setup (native config, not just Dart code).
//      Wired correctly here, but will not function until that setup
//      exists. Test username/password + guest first.
//   2. Verify OTP: VerifyOtpScreen has no "new password" field, but the
//      backend's reset-password endpoint requires one. Wired to a
//      placeholder that will fail until this is resolved with your team.

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'config/env_config.dart';
import 'config/theme_config.dart';
import 'models/models.dart';
import 'providers/auth_provider.dart';
import 'services/api_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_otp_screen.dart';

Future<void> main() async {
  // Required because we now call async code before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // MUST happen before ApiService/AuthProvider are ever constructed —
  // anything that reads EnvConfig.apiBaseUrl (which ApiService does,
  // via buildDioClient()) will throw flutter_dotenv's own
  // NotInitializedError if .env hasn't been loaded yet. This was
  // missing in the previous version of this file — that's what
  // caused the red screen on app launch.
  await EnvConfig.load();

  // google_sign_in v7+ requires a one-time initialize() call at app
  // startup, BEFORE any screen tries to call .authenticate(). It is
  // NOT called again per sign-in attempt.
  //
  // IMPORTANT WEB QUIRK: passing `serverClientId` on Flutter Web throws
  // an assertion error ("serverClientId is not supported on Web"), since
  // the web plugin only knows about `clientId`. On Android/iOS you DO
  // want serverClientId (so your FastAPI backend can verify the token
  // against the same client). This is why the two platforms need
  // different initialize() calls, not one call with both params.
  //
  // TODO: replace these placeholder strings with your real OAuth
  // client IDs from the Firebase console / Google Cloud console.
  // Wrapped in try/catch as a safety net — with only placeholder
  // credentials in place, we'd rather the app still load (and Google
  // Sign-In simply fail later when actually tapped) than have a
  // startup crash block EVERYTHING, including features that have
  // nothing to do with Google.
  try {
    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
      );
    } else {
      await GoogleSignIn.instance.initialize(
        clientId: 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com',
        serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
      );
    }
  } catch (e) {
    debugPrint('GoogleSignIn.initialize() failed (expected until real '
        'OAuth credentials are set): $e');
  }

  runApp(const SmartCommuteApp());
}

class SmartCommuteApp extends StatelessWidget {
  const SmartCommuteApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ChangeNotifierProvider makes ONE shared AuthProvider instance
    // available to every screen below it via context.read/watch.
    // Without this wrapper, each screen would need to create and
    // manage its own AuthProvider, and they'd all be out of sync.
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: MaterialApp(
        title: 'Smart Commute',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: '/login',
        routes: {
          '/login': (context) => _buildLoginScreen(context),
          '/register': (context) => _buildRegisterScreen(context),
          '/forgot-password': (context) => _buildForgotPasswordScreen(context),
          '/verify-otp': (context) => _buildVerifyOtpScreen(context),
          // TEMPORARY — replace with the real CommuterDashboard (F4)
          // once it exists. Exists now just so login/guest navigation
          // has somewhere valid to land during testing.
          '/commuter-placeholder': (context) => Scaffold(
                appBar: AppBar(title: const Text('Logged in (placeholder)')),
                body: Center(
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) => Text(
                      auth.isGuest
                          ? 'Signed in as Guest'
                          : 'Signed in — role: ${auth.role}',
                    ),
                  ),
                ),
              ),
        },
      ),
    );
  }

  // -----------------------------------------------------------------
  // LOGIN SCREEN
  // -----------------------------------------------------------------
  Widget _buildLoginScreen(BuildContext context) {
    // `read` (not `watch`) because we're inside a callback, not the
    // build method itself — we want the provider instance to call a
    // method on it, not to rebuild this widget when it changes.
    final authProvider = context.read<AuthProvider>();

    return LoginScreen(
      // Signature must be EXACTLY:
      // Future<void> Function(String usernameOrEmail, String password, bool rememberMe)
      onLogin: (usernameOrEmail, password, rememberMe) async {
        await authProvider.login(usernameOrEmail, password, rememberMe: rememberMe);
        // If login() throws, LoginScreen's own try/catch shows the
        // error banner — we don't need to handle it again here.
        // If it succeeds, navigate to the right place.
        if (context.mounted) {
          // TODO: once role-based dashboards exist, route by
          // authProvider.role instead of a single hardcoded route.
          Navigator.of(context).pushReplacementNamed('/commuter-placeholder');
        }
      },

      // Signature: Future<void> Function() — no idToken param.
      // We fetch the Google idToken HERE, then hand it to AuthProvider.
      //
      // v7 API: GoogleSignIn.instance (singleton, already initialized
      // in main()) instead of `GoogleSignIn()`. .authenticate() replaces
      // .signIn(), and unlike v6, it THROWS (GoogleSignInException)
      // rather than returning null when the user cancels the picker —
      // that's why this is in a try/catch instead of an `if (== null)`
      // check like the old v6 pattern.
      onGoogleSignIn: () async {
        try {
          final googleAccount = await GoogleSignIn.instance.authenticate();
          final idToken = googleAccount.authentication.idToken;
          if (idToken == null) {
            throw Exception('Google did not return an ID token');
          }
          await authProvider.loginWithGoogle(idToken);
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/commuter-placeholder');
          }
        } on GoogleSignInException catch (e) {
          // e.code == GoogleSignInExceptionCode.canceled when the user
          // simply closes the picker — not a real error, just do nothing.
          if (e.code != GoogleSignInExceptionCode.canceled) rethrow;
        }
      },

      // Signature: VoidCallback — synchronous, matches
      // AuthProvider.continueAsGuest() being non-async.
      onGuestContinue: () {
        authProvider.continueAsGuest();
        Navigator.of(context).pushReplacementNamed('/commuter-placeholder');
      },

      onForgotPassword: () => Navigator.of(context).pushNamed('/forgot-password'),
      onCreateAccount: () => Navigator.of(context).pushNamed('/register'),
    );
  }

  // -----------------------------------------------------------------
  // REGISTER SCREEN
  // -----------------------------------------------------------------
  Widget _buildRegisterScreen(BuildContext context) {
    final apiService = ApiService(); // registration doesn't need AuthProvider state

    return RegisterScreen(
      // Signature: Future<void> Function(username, firstName, lastName, email, password)
      onRegister: (username, firstName, lastName, email, password) async {
        await apiService.register(UserCreate(
          username: username,
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
        ));
        // Registration does NOT log the user in (no tokens returned) —
        // send them back to login to sign in with their new account.
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created — please log in.')),
          );
        }
      },

      onGoogleSignIn: () async {
        try {
          final googleAccount = await GoogleSignIn.instance.authenticate();
          final idToken = googleAccount.authentication.idToken;
          if (idToken == null) {
            throw Exception('Google did not return an ID token');
          }
          await apiService.loginWithGoogle(idToken);
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/commuter-placeholder');
          }
        } on GoogleSignInException catch (e) {
          if (e.code != GoogleSignInExceptionCode.canceled) rethrow;
        }
      },

      onBack: () => Navigator.of(context).pop(),
    );
  }

  // -----------------------------------------------------------------
  // FORGOT PASSWORD SCREEN
  // -----------------------------------------------------------------
  Widget _buildForgotPasswordScreen(BuildContext context) {
    final apiService = ApiService();

    return ForgotPasswordScreen(
      onBack: () => Navigator.of(context).pop(),
      // Signature: Future<void> Function(String email)
      onSendOtp: (email) async {
        await apiService.sendPasswordResetOtp(email);
        if (context.mounted) {
          await Navigator.of(context).pushNamed('/verify-otp', arguments: email);
        }
      },
    );
  }

  // -----------------------------------------------------------------
  // VERIFY OTP SCREEN
  // -----------------------------------------------------------------
  Widget _buildVerifyOtpScreen(BuildContext context) {
    final email = ModalRoute.of(context)?.settings.arguments as String? ??
        'account@gmail.com';
    final apiService = ApiService();

    return VerifyOtpScreen(
      email: email,
      onBack: () => Navigator.of(context).pop(),
      // Signature: Future<void> Function(String otp)
      // FLAGGED GAP (see file header): this screen has no new-password
      // field, but the backend needs one. Passing a placeholder value
      // here is WRONG and only exists so the app compiles and runs —
      // do not ship this. Resolve the missing screen/step with your
      // team before this flow is considered done.
      onVerifyOtp: (otp) async {
        // TODO: replace 'PLACEHOLDER' once a real new-password field/
        // screen exists in the flow.
        await apiService.verifyOtpAndResetPassword(email, otp, 'PLACEHOLDER');
        if (context.mounted) {
          Navigator.of(context).popUntil((route) => route.settings.name == '/login');
        }
      },
    );
  }
}