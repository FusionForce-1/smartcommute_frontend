// lib/screens/auth/register_screen.dart
//
// Emae D. Calonia — Flutter Register (Commuter only).
// Fields: Full Name, Email, Password, Repeat Password, and the User
// Agreement / Privacy Policy consent box. No role selector.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../widgets/auth/auth_header_banner.dart';
import '../../widgets/auth/smart_commute_logo.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/consent_checkbox.dart';
import '../../widgets/auth/google_button_face.dart';
import '../../widgets/auth/google_signin_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onRegister,
    this.onGoogleSignIn,
    this.onBack,
    this.onConsentChanged,
  });

  /// TODO: Velez — AuthProvider.registerCommuter(fullName, email, password)
  /// → ApiService.register(UserCreate{..., role: "commuter"})
  /// → POST /auth/register
  final Future<void> Function(
    String fullName,
    String email,
    String password,
  )? onRegister;

  /// TODO: Velez — AuthProvider.loginWithGoogle(idToken) → POST /auth/google
  final Future<void> Function()? onGoogleSignIn;

  final VoidCallback? onBack;

  /// The User Agreement / Privacy Policy box changed (also false on leaving
  /// the screen). Lets a Google sign-up started here carry the agreement.
  final ValueChanged<bool>? onConsentChanged;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();

  bool _agreed = false;
  bool _showConsentError = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    widget.onConsentChanged?.call(false);
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text != _repeatPassword.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }
    if (!_agreed) {
      setState(() => _showConsentError = true);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Velez — after 201, route to Login and notifyListeners()
      await widget.onRegister?.call(
        _fullName.text.trim(),
        _email.text.trim(),
        _password.text,
      );
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = 'Registration failed. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogle() async {
    try {
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthHeaderBanner(
                title: 'CREATE YOUR ACCOUNT',
                onBack: widget.onBack,
                centerTitle: true,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SmartCommuteLogo(height: 120)),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AuthTextField(
                        label: 'Full Name',
                        hint: 'Full Name',
                        controller: _fullName,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter your full name'
                            : null,
                      ),
                      AuthTextField(
                        label: 'Email Address',
                        hint: 'Email Address',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      AuthTextField(
                        label: 'Password',
                        hint: 'Password',
                        controller: _password,
                        obscureText: true,
                        validator: (v) => (v == null || v.length < 8)
                            ? 'Minimum 8 characters'
                            : null,
                      ),
                      AuthTextField(
                        label: 'Repeat Password',
                        hint: 'Repeat Password',
                        controller: _repeatPassword,
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Repeat your password'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ConsentCheckbox(
                        value: _agreed,
                        onChanged: (v) {
                          setState(() {
                            _agreed = v;
                            if (v) _showConsentError = false;
                          });
                          widget.onConsentChanged?.call(v);
                        },
                      ),
                      if (_showConsentError)
                        const Padding(
                          padding: EdgeInsets.only(left: 32, top: 4),
                          child: Text(
                            'Please agree to the User Agreement and Privacy Policy to continue.',
                            style: TextStyle(color: AppColors.error, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      ElevatedButton(
                        onPressed: _handleRegister,
                        child: const Text('Register'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const OrDivider(),
                      const SizedBox(height: AppSpacing.sm),
                      // Google signs up a new account too, so it waits for
                      // the box. Until then a faded stand-in shows why.
                      if (_agreed)
                        const GoogleSignInButton()
                      else
                        SizedBox(
                          height: 52,
                          child: Opacity(
                            opacity: 0.5,
                            child: GoogleButtonFace(
                              key: const Key('googleNeedsConsent'),
                              onPressed: () => setState(() => _showConsentError = true),
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
      ),
    );
  }
}
