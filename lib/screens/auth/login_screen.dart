// lib/screens/auth/login_screen.dart
//
// E2. Flutter Mobile App Screens — LoginScreen
// File: screens/auth/login_screen.dart · Role: All roles / Guest
// "Centered card layout over logo lockup. Username-or-email + password
// TextFields, 'Login' button, 'Continue as Guest' secondary button,
// 'Continue with Google' button, 'Forgot Password?' and 'Create an account'
// links. Error snackbar on failure."
//
// This screen is UI-only. All backend/state-management wiring
// is exposed as optional callback params and left as `//  TODO` for the app router / AuthProvider / ApiService to implement.
// see F1 ApiService / F3 AuthProvider in the system layout doc for the real
// implementations this should eventually call:
//   onLogin          -> AuthProvider.login() -> ApiService.login() -> POST /auth/login
//   onGoogleSignIn    -> AuthProvider.loginWithGoogle() -> POST /auth/google
//   onGuestContinue   -> AuthProvider.continueAsGuest() (local only, no request)
//
// If a callback is left null, the button falls back to a preview-only
// SnackBar so the screen still fully demos on its own with `flutter run`.

import 'package:flutter/material.dart';
  import '../../config/theme_config.dart';
  import '../../widgets/auth/smart_commute_logo.dart';
  import '../../widgets/auth/auth_text_field.dart';
  import '../../widgets/auth/google_signin_button.dart';
  import '../../widgets/loading_overlay.dart';
  import '../../widgets/error_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.onLogin,
    this.onGoogleSignIn,
    this.onGuestContinue,
    this.onForgotPassword,  
    this.onCreateAccount,
  });

  /// TODO: wire to AuthProvider.login(usernameOrEmail, password).
  final Future<void> Function(
    String usernameOrEmail,
    String password,
    bool rememberMe,
  )? onLogin;

    /// TODO: wire to AuthProvider.loginWithGoogle(idToken) — the
    /// idToken itself comes from the google_sign_in package (F8), not from
    /// this screen.
  final Future<void> Function()? onGoogleSignIn;

  /// TODO: wire to AuthProvider.continueAsGuest().
  final VoidCallback? onGuestContinue;

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.onLogin != null) {
      try {
        await widget.onLogin!(
          _usernameOrEmailController.text.trim(),
          _passwordController.text,
          _rememberMe,
        );
      } catch (e) {
        setState(() => _errorMessage = 'Invalid username/email or password.');
      }
    } else {
      // Preview-only fallback — no backend wired yet.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview only — Login not wired yet.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleGoogle() async {
    if (widget.onGoogleSignIn != null) {
      await widget.onGoogleSignIn!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview only — Google sign-in not wired yet.')),
      );
    }
  }

  void _handleGuest() {
    if (widget.onGuestContinue != null) {
      widget.onGuestContinue!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preview only — Guest mode not wired yet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.lg),
                const SmartCommuteLogo(),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.card + 12),
                    boxShadow: AppShadows.card,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          ErrorBanner(message: _errorMessage!),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        AuthTextField(
                          label: 'Username or Email',
                          hint: 'Email',
                          controller: _usernameOrEmailController,
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter your username or email'
                              : null,
                        ),
                        AuthTextField(
                          label: 'Password',
                          hint: 'Password',
                          controller: _passwordController,
                          prefixIcon: Icons.lock_outline,
                          obscureText: true,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Enter your password'
                              : null,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: (v) =>
                                        setState(() => _rememberMe = v ?? false),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('Remember Me',
                                    style: TextStyle(
                                        color: AppColors.secondary, fontSize: 13)),
                              ],
                            ),
                            TextButton(
                              onPressed: widget.onForgotPassword,
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                              child: const Text('Forgot Password?',
                                  style: TextStyle(
                                      color: AppColors.secondary, fontSize: 13)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ElevatedButton(
                          onPressed: _handleLogin,
                          child: const Text('Login'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        OutlinedButton(
                          onPressed: _handleGuest,
                          child: const Text('Continue as Guest'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const OrDivider(),
                        const SizedBox(height: AppSpacing.xs),
                        GoogleSignInButton(onPressed: _handleGoogle),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? ",
                                style: TextStyle(color: AppColors.textSecondary)),
                            GestureDetector(
                              onTap: widget.onCreateAccount,
                              child: const Text(
                                'Create an account',
                                style: TextStyle(
                                  color: AppColors.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
