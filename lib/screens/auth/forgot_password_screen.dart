// lib/screens/auth/forgot_password_screen.dart
//
// E2. Flutter Mobile App Screens — ForgotPasswordScreen
// File: screens/auth/forgot_password_screen.dart · Role: All roles
// "Teal header banner 'FORGOT PASSWORD'. Shield/lock icon, single email
// field, 'Send OTP' button. Back arrow to Login."
//
// UI-only.TODO:
//   onSendOtp -> ApiService equivalent of AuthService.send_otp(email) ->
//                POST /auth/forgot-password -> HTTP 202
//
// The mock router in main.dart wires onSendOtp to navigate straight to
// VerifyOtpScreen so the click-through prototype stays demoable without a
// backend; replace that navigation with a real await + error handling once
// F1/F3 exist.

import 'package:flutter/material.dart';
import '../../config/theme_config.dart';
import '../../widgets/auth/auth_header_banner.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/loading_overlay.dart';
import '../../widgets/error_banner.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.onSendOtp,
    this.onBack,
  });

  /// TODO: wire to the real "send OTP" API call.
  final Future<void> Function(String email)? onSendOtp;
  final VoidCallback? onBack;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _handleSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (widget.onSendOtp != null) {
      try {
        await widget.onSendOtp!(_email.text.trim());
      } catch (e) {
        setState(() => _errorMessage = 'This email is not registered.');
      }
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preview only — Send OTP not wired yet.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
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
                title: 'FORGOT\nPASSWORD',
                onBack: widget.onBack,
                big: true,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.secondary, width: 2),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.secondary,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const Text(
                        'Trouble Logging in?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Enter your email and we'll send you an OTP code to reset your password.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_errorMessage != null) ...[
                        ErrorBanner(message: _errorMessage!),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      AuthTextField(
                        label: 'Email Address',
                        hint: 'Email',
                        controller: _email,
                        prefixIcon: null,
                        pill: true,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || !v.contains('@'))
                            ? 'Enter a valid email'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      ElevatedButton(
                        onPressed: _handleSendOtp,
                        child: const Text('Send OTP'),
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
