// lib/screens/auth/login_screen.dart
//
// Emae D. Calonia — Flutter Login (Commuter / Driver).
// Centered logo lockup over ice-blue + teal split. Email + password card,
// Remember Me, Forgot Password, Login, Continue as Guest, Google, register link.
//
// This screen is UI-only. Wire AuthProvider from the parent (see auth_app.dart).

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../constants/app_icons.dart';
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

  /// TODO: Velez — AuthProvider.login(email, password, rememberMe: rememberMe)
  /// → ApiService.login() → POST /auth/login
  final Future<void> Function(
    String email,
    String password,
    bool rememberMe,
  )? onLogin;

  /// TODO: Velez — google_sign_in idToken then
  /// AuthProvider.loginWithGoogle(idToken) → POST /auth/google
  final Future<void> Function()? onGoogleSignIn;

  /// TODO: Velez — AuthProvider.continueAsGuest() (local only, no HTTP)
  final VoidCallback? onGuestContinue;

  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Velez — trigger AuthProvider.notifyListeners() after POST /auth/login
      await widget.onLogin?.call(
        _emailController.text.trim(),
        _passwordController.text,
        _rememberMe,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Invalid email or password.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    try {
      // TODO: Velez — obtain Google idToken, then POST /auth/google
      await widget.onGoogleSignIn?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Google sign-in failed. Try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundIceBlue,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: ColoredBox(color: AppColors.secondary),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    const SmartCommuteLogo(height: 148),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppRadius.card + 12),
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
                              label: 'Email',
                              hint: 'Email',
                              controller: _emailController,
                              prefixIcon: AppIcons.person,
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Enter your email';
                                }
                                if (!v.contains('@')) {
                                  return 'Enter a valid email';
                                }
                                return null;
                              },
                            ),
                            AuthTextField(
                              label: 'Password',
                              hint: 'Password',
                              controller: _passwordController,
                              prefixIcon: AppIcons.lock,
                              obscureText: true,
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _rememberMe = !_rememberMe),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _rememberMe
                                            ? AppIcons.checkboxOn
                                            : AppIcons.checkboxOff,
                                        size: 20,
                                        color: AppColors.secondary,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Remember Me',
                                        style: TextStyle(
                                          color: AppColors.secondary,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: widget.onForgotPassword,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                      fontSize: 13,
                                    ),
                                  ),
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
                              onPressed: widget.onGuestContinue,
                              child: const Text('Continue as Guest'),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const OrDivider(),
                            const SizedBox(height: AppSpacing.sm),
                            GoogleSignInButton(onPressed: _handleGoogle),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account? ",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: widget.onCreateAccount,
                                  child: const Text(
                                    'Create an account',
                                    style: TextStyle(
                                      color: AppColors.secondary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
