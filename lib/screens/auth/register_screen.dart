// lib/screens/auth/register_screen.dart
//
// E2. Flutter Mobile App Screens — RegisterScreen
// File: screens/auth/register_screen.dart · Role: New commuters
// "Teal header banner 'CREATE YOUR ACCOUNT'. Scrollable form: username,
// first name, last name, email, password, confirm password. 'Register' CTA,
// 'Continue with Google' alternative. Commuter role only — no role selector
// on this public screen."
//
// UI-only.TODO:
//   onRegister       -> ApiService.register(UserCreate) -> POST /auth/register
//   onGoogleSignIn    -> ApiService.loginWithGoogle(idToken) -> POST /auth/google

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../widgets/auth/auth_header_banner.dart';
import '../../widgets/auth/smart_commute_logo.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/google_signin_button.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.onRegister,
    this.onGoogleSignIn,
    this.onBack,
  });

  /// TODO: wire to ApiService.register(UserCreate{username, email,
  /// password, first_name, last_name, role: "commuter"}).
  final Future<void> Function(
    String username,
    String firstName,
    String lastName,
    String email,
    String password,
  )? onRegister;

  /// TODO: wire to ApiService.loginWithGoogle(idToken).
  final Future<void> Function()? onGoogleSignIn;

  final VoidCallback? onBack;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _username.dispose();
    _firstName.dispose();
    _lastName.dispose();
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.onRegister != null) {
      try {
        await widget.onRegister!(
          _username.text.trim(),
          _firstName.text.trim(),
          _lastName.text.trim(),
          _email.text.trim(),
          _password.text,
        );
      } catch (e) {
        setState(() => _errorMessage = 'Registration failed. Please try again.');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview only — Register not wired yet.')),
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
              AuthHeaderBanner(title: 'CREATE YOUR ACCOUNT', onBack: widget.onBack),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: SmartCommuteLogo(height: 110)),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AuthTextField(
                        label: 'Username',
                        hint: 'Username',
                        controller: _username,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Choose a username' : null,
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AuthTextField(
                              label: 'First Name',
                              hint: 'First Name',
                              controller: _firstName,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: AuthTextField(
                              label: 'Last Name',
                              hint: 'Last Name',
                              controller: _lastName,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                          ),
                        ],
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
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Repeat your password' : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: _handleRegister,
                        child: const Text('Register'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const OrDivider(),
                      const SizedBox(height: AppSpacing.sm),
                      GoogleSignInButton(onPressed: _handleGoogle),
                      const SizedBox(height: AppSpacing.md),
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
